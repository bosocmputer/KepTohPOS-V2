-- รันด้วย: supabase test db
-- รหัสประจำเครื่อง POS (สรรพากร ฉบับที่ 46) และ snapshot is_tax_invoice บนบิล
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(10);

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

insert into auth.users (id, email, is_anonymous) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.test', false),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.test', false),
  ('00000000-0000-0000-0000-00000000000d', null, true);

create temp table ctx (key text primary key, val text);
create function tests.val(p_key text) returns text language sql as $$ select val from ctx where key = p_key $$;
create function tests.set_val(p_key text, p_val text) returns void language sql as
  $$ insert into ctx values (p_key, p_val) on conflict (key) do update set val = excluded.val $$;

select tests.set_val('shop', tests.owner_a($$select create_organization_with_shop('กิจการ A', 'ร้าน A')$$));
select tests.set_val('shop_b', tests.owner_b($$select create_organization_with_shop('กิจการ B', 'ร้าน B')$$));
select tests.device_a(format($$select shop_id from claim_device(%L)$$,
  tests.owner_a(format($$select pairing_code from create_device_pairing(%L, 'เครื่อง A')$$, tests.val('shop')))));
select tests.set_val('device', (select id::text from devices where shop_id = tests.val('shop')::uuid));

insert into staff (id, shop_id, name, role) values
  ('10000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'แคชเชียร์ A', 'cashier');
select tests.owner_a($$select 1 from set_staff_pin('10000000-0000-0000-0000-000000000001', '1111')$$);
insert into dining_tables (id, shop_id, name, seats) values
  ('20000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'โต๊ะ 1', 4);
insert into packages (id, shop_id, name, adult_price, child_price, time_limit_min) values
  ('30000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'บุฟเฟต์', 10000, 5000, 120);
insert into payment_methods (id, shop_id, name, type) values
  ('50000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'เงินสดหลัก', 'cash');
select tests.set_val('cashier', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000001', '1111') ->> 'session_token'$$));
select tests.device_a(format($$select 1 from open_shift(%L, '90000000-0000-0000-0000-000000000000', 0, now())$$, tests.val('cashier')));

-- ขาย 1 ผู้ใหญ่ (10000) ด้วยเลขบิล p_n; ยอดรวมขึ้นกับ vat_mode ที่ตั้งไว้ จึงรับเงินเกินแล้วอ่านยอดจากฟังก์ชันคำนวณ
create function tests.sell(p_n int) returns text language plpgsql as $$
declare
  v_mode text := (select vat_mode from shops where id = tests.val('shop')::uuid);
  v_total bigint := (private.calc_bill_amounts(10000, 0, v_mode, 7, 'none')).total;
begin
  return tests.device_a(format(
    $f$select settle_bill(%L, %L, %L, '20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'before', 1, 0, 0, '{}', '50000000-0000-0000-0000-000000000001', 100000, %s, now()) ->> 'no'$f$,
    tests.val('cashier'),
    format('60000000-0000-0000-0000-00000000000%s', p_n),
    format('70000000-0000-0000-0000-00000000000%s', p_n),
    v_total));
end $$;
create function tests.flag(p_n int) returns text language sql as $$
  select is_tax_invoice::text || '/' || coalesce(rd_machine_code, '-') from bills
  where id = format('60000000-0000-0000-0000-00000000000%s', p_n)::uuid
$$;

-- 1) จด VAT + ร้านใช้ VAT แต่เครื่องไม่มีรหัส => ไม่ใช่ใบกำกับภาษี
update organizations set vat_registered = true where id = (select org_id from shops where id = tests.val('shop')::uuid);
update shops set vat_mode = 'included' where id = tests.val('shop')::uuid;
select tests.sell(1);
select is(tests.flag(1), 'false/-', 'ไม่มีรหัสเครื่อง => is_tax_invoice false');

-- 2) เจ้าของร้านตั้งรหัสได้; รูปแบบผิดถูกปฏิเสธ
select is(tests.owner_a(format($$update devices set rd_machine_code = 'bad code!' where id = %L returning 1$$, tests.val('device'))), 'ERR:23514', 'รหัสเครื่องรูปแบบผิดถูกปฏิเสธ');
select is(tests.owner_a(format($$update devices set rd_machine_code = repeat('A', 21) where id = %L returning 1$$, tests.val('device'))), 'ERR:23514', 'รหัสเครื่องยาวเกิน 20 ถูกปฏิเสธ');
select is(tests.owner_a(format($$update devices set rd_machine_code = 'ABC-123' where id = %L returning 1$$, tests.val('device'))), '1', 'ตั้งรหัสสำเร็จ 1 แถว');
select is((select rd_machine_code from devices where id = tests.val('device')::uuid), 'ABC-123', 'เจ้าของร้านตั้งรหัสเครื่องได้');

-- 3) ผู้ไม่มีสิทธิ์จัดการร้านตั้งไม่ได้ (RLS กรองเป็น 0 แถว)
select tests.device_a(format($$update devices set rd_machine_code = 'HACK' where id = %L returning 1$$, tests.val('device')));
select tests.owner_b(format($$update devices set rd_machine_code = 'HACK' where id = %L returning 1$$, tests.val('device')));
select is((select rd_machine_code from devices where id = tests.val('device')::uuid), 'ABC-123', 'เครื่องเองและเจ้าของร้านอื่นแก้รหัสไม่ได้');

-- 4) ครบ 3 เงื่อนไข => true และเก็บรหัสไว้บนบิล
select tests.sell(2);
select is(tests.flag(2), 'true/ABC-123', 'จด VAT + ร้านใช้ VAT + มีรหัส => is_tax_invoice true');

-- 5) ร้านไม่ใช้ VAT => false
update shops set vat_mode = 'none' where id = tests.val('shop')::uuid;
select tests.sell(3);
select is(tests.flag(3), 'false/ABC-123', 'vat_mode none => false');

-- 6) ไม่จด VAT => false
update shops set vat_mode = 'none' where id = tests.val('shop')::uuid;
update organizations set vat_registered = false where id = (select org_id from shops where id = tests.val('shop')::uuid);
select tests.sell(4);
select is(tests.flag(4), 'false/ABC-123', 'ไม่จด VAT => false');

-- 7) เปลี่ยนรหัสเครื่องภายหลัง snapshot บนบิลเดิมต้องไม่เปลี่ยน
update devices set rd_machine_code = 'NEW-999' where id = tests.val('device')::uuid;
select is(tests.flag(2), 'true/ABC-123', 'เปลี่ยนรหัสเครื่องแล้ว snapshot ของบิลเดิมไม่เปลี่ยน');

select * from finish();
rollback;
