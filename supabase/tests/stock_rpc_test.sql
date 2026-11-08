-- รันด้วย: supabase test db
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(38);

create schema tests;
create function tests.q(p_role text, p_uid uuid, p_anon boolean, p_sql text) returns text
language plpgsql
as $$
declare
  r text;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_uid, 'role', p_role, 'is_anonymous', p_anon)::text, true);
  execute format('set local role %I', p_role);
  execute p_sql into r;
  reset role;
  return r;
exception when others then
  return 'ERR:' || sqlstate;
end;
$$;
create function tests.owner_a(p_sql text) returns text language sql as
  $$ select tests.q('authenticated', '00000000-0000-0000-0000-00000000000a', false, p_sql) $$;
create function tests.owner_b(p_sql text) returns text language sql as
  $$ select tests.q('authenticated', '00000000-0000-0000-0000-00000000000b', false, p_sql) $$;
create function tests.device_a(p_sql text) returns text language sql as
  $$ select tests.q('authenticated', '00000000-0000-0000-0000-00000000000d', true, p_sql) $$;
create function tests.device_b(p_sql text) returns text language sql as
  $$ select tests.q('authenticated', '00000000-0000-0000-0000-00000000000e', true, p_sql) $$;

insert into auth.users (id, email, is_anonymous) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.test', false),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.test', false),
  ('00000000-0000-0000-0000-00000000000d', null, true),
  ('00000000-0000-0000-0000-00000000000e', null, true);

create temp table ctx (key text primary key, val text);
create function tests.val(p_key text) returns text language sql as $$ select val from ctx where key = p_key $$;
create function tests.set_val(p_key text, p_val text) returns void language sql as
  $$ insert into ctx values (p_key, p_val) on conflict (key) do update set val = excluded.val $$;

select tests.set_val('shop', tests.owner_a($$select create_organization_with_shop('กิจการ A', 'ร้าน A')$$));
select tests.set_val('shop_b', tests.owner_b($$select create_organization_with_shop('กิจการ B', 'ร้าน B')$$));
select tests.device_a(format($$select shop_id from claim_device(%L)$$,
  tests.owner_a(format($$select pairing_code from create_device_pairing(%L, 'เครื่อง A')$$, tests.val('shop')))));
select tests.device_b(format($$select shop_id from claim_device(%L)$$,
  tests.owner_b(format($$select pairing_code from create_device_pairing(%L, 'เครื่อง B')$$, tests.val('shop_b')))));

insert into staff (id, shop_id, name, role) values
  ('10000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'แคชเชียร์ A', 'cashier'),
  ('10000000-0000-0000-0000-000000000002', tests.val('shop')::uuid, 'ผู้จัดการ A', 'manager'),
  ('10000000-0000-0000-0000-000000000003', tests.val('shop_b')::uuid, 'แคชเชียร์ B', 'cashier');
select x.* from (
  select tests.owner_a($$select 1 from set_staff_pin('10000000-0000-0000-0000-000000000001', '1111')$$),
         tests.owner_a($$select 1 from set_staff_pin('10000000-0000-0000-0000-000000000002', '2222')$$),
         tests.owner_b($$select 1 from set_staff_pin('10000000-0000-0000-0000-000000000003', '3333')$$)
) x;

insert into suppliers (id, shop_id, name) values
  ('20000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'ซัพพลายเออร์ A'),
  ('20000000-0000-0000-0000-000000000009', tests.val('shop_b')::uuid, 'ซัพพลายเออร์ B');
insert into ingredients (id, shop_id, name, unit) values
  ('30000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'หมู', 'กก.'),
  ('30000000-0000-0000-0000-000000000009', tests.val('shop_b')::uuid, 'หมูร้าน B', 'กก.');
insert into expense_types (id, shop_id, name) values
  ('40000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'แก๊สทดสอบ'),
  ('40000000-0000-0000-0000-000000000009', tests.val('shop_b')::uuid, 'แก๊สร้าน B');

create function tests.sign_in(p_staff text, p_pin text) returns void language sql as $$
  select tests.set_val('token', tests.device_a(format($f$select verify_staff_pin(%L, %L) ->> 'session_token'$f$, p_staff, p_pin)));
$$;
select tests.sign_in('10000000-0000-0000-0000-000000000001', '1111');
select tests.set_val('token_b', tests.device_b($$select verify_staff_pin('10000000-0000-0000-0000-000000000003', '3333') ->> 'session_token'$$));

create function tests.purchase_sql(p_id text, p_lines text, p_is_edit boolean default false, p_token text default null, p_supplier text default '20000000-0000-0000-0000-000000000001') returns text language sql as $$
  select format(
    $f$select record_purchase(%L, %L, '2026-11-07', %L, ' รับช่วงเช้า ', %L, now(), %L)$f$,
    coalesce(p_token, tests.val('token')), p_id, p_supplier, p_lines, p_is_edit
  )
$$;
create function tests.expense_sql(p_lines text, p_token text default null) returns text language sql as $$
  select format($f$select record_expenses(%L, '2026-11-07', %L, now())$f$, coalesce(p_token, tests.val('token')), p_lines)
$$;

-- การซื้อ: แคชเชียร์เพิ่มใหม่ได้
select is(tests.device_a(tests.purchase_sql('50000000-0000-0000-0000-000000000001', '[{"ingredient_id":"30000000-0000-0000-0000-000000000001","qty":5,"total":95000}]')), 'true', 'แคชเชียร์เพิ่มบิลซื้อได้');
select is((select note from purchases where id = '50000000-0000-0000-0000-000000000001'), 'รับช่วงเช้า', 'ตัดช่องว่างของโน้ต');
select is((select total from purchase_lines where purchase_id = '50000000-0000-0000-0000-000000000001'), 95000::bigint, 'บันทึกยอดรายการ');
select is(tests.device_a(tests.purchase_sql('50000000-0000-0000-0000-000000000001', '[{"ingredient_id":"30000000-0000-0000-0000-000000000001","qty":5,"total":95000}]')), 'true', 'ส่งซ้ำด้วย id เดิมคืน true');
select is((select count(*)::int from purchase_lines where shop_id = tests.val('shop')::uuid), 1, 'ส่งซ้ำแล้วไม่เกิดรายการใหม่');
select is(tests.device_a(tests.purchase_sql('50000000-0000-0000-0000-000000000002', '[]')), 'ERR:22023', 'บิลซื้อว่างไม่ได้');
select is(tests.device_a(tests.purchase_sql('50000000-0000-0000-0000-000000000002', '[{"ingredient_id":"30000000-0000-0000-0000-000000000001","qty":0,"total":100}]')), 'ERR:22023', 'จำนวนต้องมากกว่า 0');
select is(tests.device_a(tests.purchase_sql('50000000-0000-0000-0000-000000000002', '[{"ingredient_id":"30000000-0000-0000-0000-000000000009","qty":1,"total":100}]')), 'ERR:22023', 'ใช้วัตถุดิบร้านอื่นไม่ได้');
select is(tests.device_a(tests.purchase_sql('50000000-0000-0000-0000-000000000002', '[{"ingredient_id":"30000000-0000-0000-0000-000000000001","qty":1,"total":100}]', false, null, '20000000-0000-0000-0000-000000000009')), 'ERR:22023', 'ใช้ซัพพลายเออร์ร้านอื่นไม่ได้');
select is(tests.device_a(tests.purchase_sql('50000000-0000-0000-0000-000000000001', '[{"ingredient_id":"30000000-0000-0000-0000-000000000001","qty":8,"total":150000}]', true)), 'ERR:42501', 'แคชเชียร์แก้บิลซื้อไม่ได้');
select is(tests.device_a(format($$select remove_purchase(%L, '50000000-0000-0000-0000-000000000001')$$, tests.val('token'))), 'ERR:42501', 'แคชเชียร์ลบบิลซื้อไม่ได้');

-- ค่าใช้จ่าย: แคชเชียร์เพิ่มใหม่ได้
select is(tests.device_a(tests.expense_sql('[{"id":"60000000-0000-0000-0000-000000000001","type_id":"40000000-0000-0000-0000-000000000001","amount":25000,"note":" น้ำแข็ง "}]')), 'true', 'แคชเชียร์เพิ่มค่าใช้จ่ายได้');
select is((select type_name || '|' || note from expenses where id = '60000000-0000-0000-0000-000000000001'), 'แก๊สทดสอบ|น้ำแข็ง', 'สแนปช็อตชื่อประเภทและตัดช่องว่าง');
select tests.device_a(tests.expense_sql('[{"id":"60000000-0000-0000-0000-000000000001","type_id":"40000000-0000-0000-0000-000000000001","amount":25000,"note":"x"}]'));
select is((select count(*)::int from expenses where shop_id = tests.val('shop')::uuid), 1, 'ส่งซ้ำไม่เกิดค่าใช้จ่ายซ้ำ');
select is(tests.device_a(tests.expense_sql('[{"id":"60000000-0000-0000-0000-000000000002","type_id":"40000000-0000-0000-0000-000000000001","amount":0}]')), 'ERR:22023', 'ยอดต้องมากกว่า 0');
select is(tests.device_a(tests.expense_sql('[{"id":"60000000-0000-0000-0000-000000000002","type_id":"40000000-0000-0000-0000-000000000009","amount":100}]')), 'ERR:22023', 'ใช้ประเภทค่าใช้จ่ายร้านอื่นไม่ได้');
select is(tests.device_a(format($$select update_expense(%L, '60000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 30000, 'x')$$, tests.val('token'))), 'ERR:42501', 'แคชเชียร์แก้ค่าใช้จ่ายไม่ได้');
select is(tests.device_a(format($$select remove_expense(%L, '60000000-0000-0000-0000-000000000001')$$, tests.val('token'))), 'ERR:42501', 'แคชเชียร์ลบค่าใช้จ่ายไม่ได้');

-- นับสต็อก
select is(tests.device_a(format($$select 1 from save_stock_count(%L, '2026-11-07', '{}', now())$$, tests.val('token'))), 'ERR:22023', 'ยอดนับว่างไม่ได้');
select is(tests.device_a(format($$select 1 from save_stock_count(%L, '2026-11-07', '{"30000000-0000-0000-0000-000000000009": 1}', now())$$, tests.val('token'))), 'ERR:22023', 'นับวัตถุดิบร้านอื่นไม่ได้');
select is(tests.device_a(format($$select 1 from save_stock_count(%L, '2026-11-07', '{"30000000-0000-0000-0000-000000000001": -1}', now())$$, tests.val('token'))), 'ERR:22023', 'ยอดนับติดลบไม่ได้');
select is(tests.device_a(format($$select 1 from save_stock_count(%L, '2026-11-07', '{"30000000-0000-0000-0000-000000000001": 3.5}', now())$$, tests.val('token'))), '1', 'แคชเชียร์บันทึกยอดนับได้');
select tests.device_a(format($$select 1 from save_stock_count(%L, '2026-11-07', '{"30000000-0000-0000-0000-000000000001": 4}', now())$$, tests.val('token')));
select is((select qty from stock_counts where business_date = '2026-11-07'), 4::numeric, 'นับซ้ำแทนที่ค่าเดิม');
select is(tests.device_a(format($$select reopen_day(%L, '2026-11-07')$$, tests.val('token'))), 'ERR:42501', 'แคชเชียร์เปิดวันที่ปิดแล้วไม่ได้');

-- ผู้จัดการแก้/ลบ/เปิดวันได้
select tests.sign_in('10000000-0000-0000-0000-000000000002', '2222');
select is(tests.device_a(tests.purchase_sql('50000000-0000-0000-0000-000000000001', '[{"ingredient_id":"30000000-0000-0000-0000-000000000001","qty":8,"total":150000}]', true)), 'true', 'ผู้จัดการแก้บิลซื้อได้');
select is((select total from purchase_lines where purchase_id = '50000000-0000-0000-0000-000000000001'), 150000::bigint, 'แก้แล้วแทนที่รายการเดิม');
select is(tests.device_a(tests.purchase_sql('50000000-0000-0000-0000-000000000099', '[{"ingredient_id":"30000000-0000-0000-0000-000000000001","qty":1,"total":1}]', true)), 'false', 'แก้บิลที่ไม่มีคืน false');
select is(tests.device_b(format($$select remove_purchase(%L, '50000000-0000-0000-0000-000000000001')$$, tests.val('token_b'))), 'ERR:42501', 'แคชเชียร์ร้าน B ลบไม่ได้');
select is(tests.device_a(format($$select update_expense(%L, '60000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 30000, ' แก้ยอด ')$$, tests.val('token'))), 'true', 'ผู้จัดการแก้ค่าใช้จ่ายได้');
select is((select amount from expenses where id = '60000000-0000-0000-0000-000000000001'), 30000::bigint, 'แก้ยอดสำเร็จ');
select is(tests.device_a(format($$select remove_expense(%L, '60000000-0000-0000-0000-000000000001')$$, tests.val('token'))), 'true', 'ผู้จัดการลบค่าใช้จ่ายได้');
select is(tests.device_a(format($$select remove_expense(%L, '60000000-0000-0000-0000-000000000001')$$, tests.val('token'))), 'false', 'ลบซ้ำคืน false');
select is(tests.device_a(format($$select remove_purchase(%L, '50000000-0000-0000-0000-000000000001')$$, tests.val('token'))), 'true', 'ผู้จัดการลบบิลซื้อได้');
select is((select count(*)::int from purchase_lines where shop_id = tests.val('shop')::uuid), 0, 'ลบบิลแล้วรายการหายด้วย');
select is(tests.device_a(format($$select reopen_day(%L, '2026-11-07')$$, tests.val('token'))), 'true', 'ผู้จัดการเปิดวันที่ปิดแล้วได้');
select is(tests.device_a(format($$select reopen_day(%L, '2026-11-07')$$, tests.val('token'))), 'false', 'เปิดซ้ำคืน false');

-- ไม่มี session / คนละร้าน
select is(tests.device_a(tests.purchase_sql('50000000-0000-0000-0000-000000000003', '[{"ingredient_id":"30000000-0000-0000-0000-000000000001","qty":1,"total":1}]', false, 'wrong-token')), 'ERR:42501', 'token ผิดใช้ไม่ได้');
select is(tests.owner_a(tests.purchase_sql('50000000-0000-0000-0000-000000000003', '[{"ingredient_id":"30000000-0000-0000-0000-000000000001","qty":1,"total":1}]')), 'ERR:42501', 'บัญชีเจ้าของใช้ token ของเครื่องไม่ได้');

select * from finish();
rollback;
