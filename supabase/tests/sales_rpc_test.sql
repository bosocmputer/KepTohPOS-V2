-- รันด้วย: supabase test db
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(101);

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
update shops set day_cutoff_minutes = 300 where id = tests.val('shop')::uuid;

select tests.device_a(format($$select shop_id from claim_device(%L)$$,
  tests.owner_a(format($$select pairing_code from create_device_pairing(%L, 'เครื่อง A')$$, tests.val('shop')))));
select tests.device_b(format($$select shop_id from claim_device(%L)$$,
  tests.owner_b(format($$select pairing_code from create_device_pairing(%L, 'เครื่อง B')$$, tests.val('shop_b')))));

insert into staff (id, shop_id, name, role) values
  ('10000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'แคชเชียร์ A', 'cashier'),
  ('10000000-0000-0000-0000-000000000002', tests.val('shop')::uuid, 'ผู้จัดการ A', 'manager'),
  ('10000000-0000-0000-0000-000000000003', tests.val('shop_b')::uuid, 'แคชเชียร์ B', 'cashier');
select set_staff_pin_row.* from (
  select tests.owner_a($$select 1 from set_staff_pin('10000000-0000-0000-0000-000000000001', '1111')$$),
         tests.owner_a($$select 1 from set_staff_pin('10000000-0000-0000-0000-000000000002', '2222')$$),
         tests.owner_b($$select 1 from set_staff_pin('10000000-0000-0000-0000-000000000003', '3333')$$)
) set_staff_pin_row;

insert into dining_tables (id, shop_id, name, seats) values
  ('20000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'โต๊ะ 1', 4),
  ('20000000-0000-0000-0000-000000000002', tests.val('shop')::uuid, 'โต๊ะ 2', 4);
insert into packages (id, shop_id, name, adult_price, child_price, time_limit_min) values
  ('30000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'บุฟเฟต์', 29900, 14900, 120);
insert into addons (id, shop_id, name, price, cost, stock) values
  ('40000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'น้ำอัดลม', 6000, 2500, 10),
  ('40000000-0000-0000-0000-000000000009', tests.val('shop_b')::uuid, 'ของร้าน B', 100, 50, 10);
insert into payment_methods (id, shop_id, name, type) values
  ('50000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'เงินสดหลัก', 'cash'),
  ('50000000-0000-0000-0000-000000000002', tests.val('shop')::uuid, 'พร้อมเพย์หลัก', 'qr');
insert into expenses (id, shop_id, business_date, at, type_name, amount) values
  (gen_random_uuid(), tests.val('shop')::uuid, '2026-11-07', now(), 'แก๊ส', 50000);
insert into fixed_costs (shop_id, name, amount) values (tests.val('shop')::uuid, 'ค่าเช่าทดสอบ', 1000000);

-- สูตรคำนวณ: ค่าคาดหวังชุดเดียวกับ app/test/unit/order_calc_parity_test.dart
select is(private.calc_bill_amounts(59800, 0, 'none', 7, 'down')::text, '(0,0,0,59800)', 'สูตร: ไม่มี VAT');
select is(private.calc_bill_amounts(59800, 0, 'excluded', 7, 'none')::text, '(0,4186,0,63986)', 'สูตร: VAT แยกนอก ไม่ปัด');
select is(private.calc_bill_amounts(59800, 0, 'excluded', 7, 'down')::text, '(0,4186,-86,63900)', 'สูตร: VAT แยกนอก ปัดลง');
select is(private.calc_bill_amounts(59800, 0, 'included', 7, 'down')::text, '(0,3912,0,59800)', 'สูตร: VAT รวมใน');
select is(private.calc_bill_amounts(29950, 10, 'none', 7, 'down')::text, '(2995,0,-45,32900)', 'สูตร: ค่าบริการ ปัดลง');
select is(private.calc_bill_amounts(29950, 10, 'excluded', 7, 'none')::text, '(2995,2306,0,35251)', 'สูตร: ค่าบริการ + VAT แยกนอก');
select is(private.calc_bill_amounts(10050, 0, 'included', 7, 'down')::text, '(0,654,-50,10000)', 'สูตร: VAT รวมในคิดจากยอดหลังปัด');
select is(private.calc_bill_amounts(150, 1, 'none', 7, 'none')::text, '(2,0,0,152)', 'สูตร: ครึ่งสตางค์ปัดขึ้น');
select is(private.calc_bill_amounts(10000, 0, 'excluded', 0, 'none')::text, '(0,0,0,10000)', 'สูตร: อัตรา VAT 0');

-- Session พนักงาน
select tests.set_val('cashier', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000001', '1111') ->> 'session_token'$$));
select tests.set_val('token_b', tests.device_b($$select verify_staff_pin('10000000-0000-0000-0000-000000000003', '3333') ->> 'session_token'$$));
select ok(length(tests.val('cashier')) = 64, 'PIN ถูกต้องบนเครื่องได้ session token');
select is(tests.owner_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000001', '1111') ? 'session_token'$$), 'false', 'เจ้าของไม่มีเครื่องจะไม่ได้ session token');
select is((select count(*)::int from private.staff_sessions where token_hash = tests.val('cashier')), 0, 'ไม่เก็บ token ดิบในฐานข้อมูล');
select is(tests.owner_a('select count(*) from private.staff_sessions'), 'ERR:42501', 'อ่านตาราง session ตรงไม่ได้');

create function tests.settle(
  p_token text, p_bill text, p_session text, p_a int, p_c int, p_f int, p_addons text,
  p_method text, p_received bigint, p_expected bigint, p_timing text default 'before', p_at text default '2026-11-07 19:00:00+07'
) returns text language sql as $$
  select format(
    $f$select settle_bill(%L, %L, %L, '20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', %L, %s, %s, %s, %L, %L, %s, %s, %L) ->> 'total'$f$,
    p_token, p_bill, p_session, p_timing, p_a, p_c, p_f, p_addons, p_method, p_received, p_expected, p_at
  )
$$;
create function tests.addon_stock() returns integer language sql as
  $$ select stock from addons where id = '40000000-0000-0000-0000-000000000001' $$;

select is(tests.device_a(tests.settle('wrong-token', '60000000-0000-0000-0000-000000000099', '70000000-0000-0000-0000-000000000099', 1, 0, 0, '{}', '50000000-0000-0000-0000-000000000001', 29900, 29900)), 'ERR:42501', 'token ผิดคิดเงินไม่ได้');
select is(tests.device_b(tests.settle(tests.val('cashier'), '60000000-0000-0000-0000-000000000099', '70000000-0000-0000-0000-000000000099', 1, 0, 0, '{}', '50000000-0000-0000-0000-000000000001', 29900, 29900)), 'ERR:42501', 'เครื่องอื่นใช้ token นี้ไม่ได้');

select is(tests.device_a(tests.settle(tests.val('cashier'), '60000000-0000-0000-0000-000000000099', '70000000-0000-0000-0000-000000000099', 1, 0, 0, '{}', '50000000-0000-0000-0000-000000000001', 29900, 29900)), 'ERR:22023', 'ไม่มีกะเปิดคิดเงินไม่ได้');
select is(tests.device_a(format($$select 1 from open_shift(%L, '90000000-0000-0000-0000-000000000000', 100000, now())$$, tests.val('cashier'))), '1', 'แคชเชียร์เปิดกะได้');

-- คิดเงินแบบจ่ายก่อนกิน: 2 ผู้ใหญ่ + 1 เด็ก + น้ำ 2 ขวด = 86,700 สตางค์
select is(tests.device_a(tests.settle(tests.val('cashier'), '60000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', 2, 1, 0, '{"40000000-0000-0000-0000-000000000001": 2}', '50000000-0000-0000-0000-000000000001', 100000, 1)), 'ERR:P0001', 'ยอดไม่ตรงกับเซิร์ฟเวอร์ถูกปฏิเสธ');
select is((select count(*)::int from bills where shop_id = tests.val('shop')::uuid), 0, 'ยอดไม่ตรงแล้วไม่มีบิล');
select is(tests.addon_stock(), 10, 'ยอดไม่ตรงแล้วไม่ตัดสต็อก');
select is(tests.device_a(tests.settle(tests.val('cashier'), '60000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', 2, 1, 0, '{"40000000-0000-0000-0000-000000000001": 2}', '50000000-0000-0000-0000-000000000001', 1000, 86700)), 'ERR:22023', 'รับเงินสดน้อยกว่ายอดไม่ได้');
select is(tests.device_a(tests.settle(tests.val('cashier'), '60000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', 1, 0, 0, '{"40000000-0000-0000-0000-000000000009": 1}', '50000000-0000-0000-0000-000000000001', 100000, 29900)), 'ERR:22023', 'ใช้ addon ของร้านอื่นไม่ได้');
select is(tests.device_a(tests.settle(tests.val('cashier'), '60000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', 0, 0, 0, '{}', '50000000-0000-0000-0000-000000000001', 0, 0)), 'ERR:22023', 'บิลว่างไม่ได้');
select is(tests.device_a(tests.settle(tests.val('cashier'), '60000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', 2, 1, 0, '{"40000000-0000-0000-0000-000000000001": 2}', '50000000-0000-0000-0000-000000000001', 100000, 86700, 'before', '2026-11-08 02:00:00+07')), '86700', 'คิดเงินสำเร็จ');

select is((select no from bills where id = '60000000-0000-0000-0000-000000000001'), '00000-POS01-000001', 'เลขใบเสร็จตามชุดของเครื่อง');
select is((select business_date::text from bills where id = '60000000-0000-0000-0000-000000000001'), '2026-11-07', '02:00 น. นับเป็นวันทำการก่อนหน้า (ตัดรอบ 05:00)');
select is((select staff_name from bills where id = '60000000-0000-0000-0000-000000000001'), 'แคชเชียร์ A', 'ผู้ทำรายการมาจาก session');
select is((select change_amount from bills where id = '60000000-0000-0000-0000-000000000001'), 13300::bigint, 'เงินทอนถูกต้อง');
select is((select count(*)::int from bill_lines where bill_id = '60000000-0000-0000-0000-000000000001'), 3, 'มี 3 รายการ');
select is((select cost from bill_lines where bill_id = '60000000-0000-0000-0000-000000000001' and type = 'addon'), 2500::bigint, 'สแนปช็อตต้นทุนลงรายการ');
select is(tests.addon_stock(), 8, 'ตัดสต็อก 2 ขวด');
select is(tests.device_a(tests.settle(tests.val('cashier'), '60000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', 2, 1, 0, '{"40000000-0000-0000-0000-000000000001": 2}', '50000000-0000-0000-0000-000000000001', 100000, 86700)), '86700', 'ส่งซ้ำ id เดิมคืนบิลเดิม');
select is((select count(*)::int from bills where shop_id = tests.val('shop')::uuid), 1, 'ส่งซ้ำแล้วไม่เกิดบิลใหม่');
select is(tests.addon_stock(), 8, 'ส่งซ้ำแล้วไม่ตัดสต็อกซ้ำ');
select is(tests.device_b(tests.settle(tests.val('token_b'), '60000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000098', 1, 0, 0, '{}', '50000000-0000-0000-0000-000000000001', 100, 100)), 'ERR:42501', 'ร้านอื่นส่ง id บิลนี้ไม่ได้');
select is(tests.device_a(format($$select settle_bill(%L, '60000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'before', 2, 1, 0, '{"40000000-0000-0000-0000-000000000001": 2}', '50000000-0000-0000-0000-000000000001', 100000, 86700, now()) -> 'lines' -> 2 ? 'cost'$$, tests.val('cashier'))), 'false', 'ผลลัพธ์ที่ส่งกลับเครื่องไม่มีต้นทุน');

-- โต๊ะเดียวเปิดซ้อนกันไม่ได้
select is(tests.device_a(tests.settle(tests.val('cashier'), '60000000-0000-0000-0000-000000000002', '70000000-0000-0000-0000-000000000002', 1, 0, 0, '{}', '50000000-0000-0000-0000-000000000001', 29900, 29900)), 'ERR:23505', 'โต๊ะเดียวเปิดสองรอบพร้อมกันไม่ได้');

-- ยกเลิกบิล
select is(tests.device_a(format($$select void_bill(%L, '60000000-0000-0000-0000-000000000001', '  ', now())$$, tests.val('cashier'))), 'true', 'แคชเชียร์ยกเลิกบิลของโต๊ะที่เปิดอยู่ได้');
select is((select void_reason from bills where id = '60000000-0000-0000-0000-000000000001'), 'ไม่ระบุ', 'เหตุผลว่างบันทึกเป็น ไม่ระบุ');
select is(tests.addon_stock(), 10, 'ยกเลิกแล้วคืนสต็อก');
select ok((select closed_at is not null from table_sessions where id = '70000000-0000-0000-0000-000000000001'), 'ไม่เหลือบิลใช้งาน โต๊ะปิดเอง');
select is(tests.device_a(format($$select void_bill(%L, '60000000-0000-0000-0000-000000000001', 'x', now())$$, tests.val('cashier'))), 'false', 'ยกเลิกซ้ำคืน false');

-- กินก่อนจ่าย: ส่ง 2 ผู้ใหญ่ + น้ำ 3 แล้วลด 1 ผู้ใหญ่ + น้ำ 1 = 41,900
select is(tests.device_a(format($$select 1 from send_round(%L, '80000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', 'after', 2, 0, 0, '{"40000000-0000-0000-0000-000000000001": 3}', now())$$, tests.val('cashier'))), '1', 'ส่งรอบสั่งได้');
select tests.device_a(format($$select 1 from send_round(%L, '80000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', 'after', 2, 0, 0, '{"40000000-0000-0000-0000-000000000001": 3}', now())$$, tests.val('cashier')));
select is((select count(*)::int from table_rounds where shop_id = tests.val('shop')::uuid), 1, 'ส่งรอบซ้ำไม่บันทึกซ้ำ');
select is(tests.addon_stock(), 7, 'ส่งรอบแล้วตัดสต็อกครั้งเดียว');
select is(tests.device_a(format($$select adjust_sent(%L, '81000000-0000-0000-0000-000000000009', '70000000-0000-0000-0000-000000000003', 'head', 'a', 1, 'ไม่ควรผ่าน', now())$$, tests.val('cashier'))), 'ERR:42501', 'แคชเชียร์ลดรายการที่ส่งแล้วไม่ได้');
select tests.set_val('manager', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000002', '2222') ->> 'session_token'$$));
select is(tests.device_a(format($$select adjust_sent(%L, '81000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000003', 'head', 'a', 1, 'คีย์ผิด', now())$$, tests.val('manager'))), 'true', 'ลดจำนวนคนได้');
select is(tests.device_a(format($$select adjust_sent(%L, '81000000-0000-0000-0000-000000000002', '70000000-0000-0000-0000-000000000003', 'addon', '40000000-0000-0000-0000-000000000001', 5, 'คีย์ผิด', now())$$, tests.val('manager'))), 'true', 'ลดน้ำเกินจำนวน ระบบลดเท่าที่มี');
select is(tests.addon_stock(), 10, 'ลดรายการแล้วคืนสต็อกเท่าที่ลดจริง');
select is(tests.device_a(format($$select adjust_sent(%L, '81000000-0000-0000-0000-000000000003', '70000000-0000-0000-0000-000000000003', 'addon', '40000000-0000-0000-0000-000000000001', 1, 'x', now())$$, tests.val('manager'))), 'false', 'ไม่มีให้ลดแล้วคืน false');
select tests.set_val('cashier', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000001', '1111') ->> 'session_token'$$));
select is(tests.device_a(format($$select 1 from close_table(%L, '70000000-0000-0000-0000-000000000003', now())$$, tests.val('cashier'))), 'ERR:22023', 'เก็บโต๊ะที่ยังมียอดค้างไม่ได้');
create function tests.settle_after(p_bill text, p_expected bigint) returns text language sql as $$
  select format(
    $f$select settle_bill(%L, %L, '70000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', 'after', 0, 0, 0, '{}', '50000000-0000-0000-0000-000000000002', 0, %s, now()) ->> 'received'$f$,
    tests.val('cashier'), p_bill, p_expected
  )
$$;
select is(tests.device_a(tests.settle_after('60000000-0000-0000-0000-000000000003', 29900)), '29900', 'คิดเงินจากรอบหลังหักรายการ และ QR รับเท่ายอด');
select is(tests.device_a(tests.settle_after('60000000-0000-0000-0000-000000000004', 29900)), 'ERR:22023', 'รอบที่คิดเงินแล้วคิดซ้ำไม่ได้');
select is((select count(*)::int from settled_table_events where shop_id = tests.val('shop')::uuid), 3, 'บันทึกเหตุการณ์ที่คิดเงินแล้วครบ');
select is((select no from bills where id = '60000000-0000-0000-0000-000000000003'), '00000-POS01-000002', 'เลขใบเสร็จเดินต่อ');
select is(tests.device_a(format($$select 1 from close_table(%L, '70000000-0000-0000-0000-000000000003', now())$$, tests.val('cashier'))), '1', 'เก็บโต๊ะได้');
select is(tests.device_a(format($$select void_bill(%L, '60000000-0000-0000-0000-000000000003', 'x', now())$$, tests.val('cashier'))), 'ERR:42501', 'แคชเชียร์ยกเลิกบิลของโต๊ะที่ปิดแล้วไม่ได้');

-- ยกเลิกโต๊ะที่ยังไม่จ่าย: คืนสต็อกแล้วปิดโต๊ะ
select tests.device_a(format($$select 1 from send_round(%L, '80000000-0000-0000-0000-000000000002', '70000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', 'after', 1, 0, 0, '{"40000000-0000-0000-0000-000000000001": 4}', now())$$, tests.val('cashier')));
select is(tests.addon_stock(), 6, 'ส่งรอบใหม่ตัดสต็อก 4');
select is(tests.device_a(format($$select set_table_notes(%L, '70000000-0000-0000-0000-000000000004', ' ไม่ใส่ผัก ')$$, tests.val('cashier'))), 'true', 'แก้โน้ตโต๊ะที่เปิดอยู่ได้');
select is((select notes from table_sessions where id = '70000000-0000-0000-0000-000000000004'), 'ไม่ใส่ผัก', 'บันทึกโน้ตแล้วตัดช่องว่าง');
select is(tests.device_b(format($$select set_table_notes(%L, '70000000-0000-0000-0000-000000000004', 'x')$$, tests.val('token_b'))), 'false', 'ร้านอื่นแก้โน้ตโต๊ะนี้ไม่ได้');
select is(tests.device_a(format($$select 1 from cancel_table(%L, '70000000-0000-0000-0000-000000000004', now())$$, tests.val('cashier'))), '1', 'ยกเลิกโต๊ะที่ยังมียอดค้างได้');
select is(tests.addon_stock(), 10, 'ยกเลิกโต๊ะแล้วคืนสต็อก');
select ok((select closed_at is not null from table_sessions where id = '70000000-0000-0000-0000-000000000004'), 'ยกเลิกแล้วโต๊ะปิด');
select tests.device_a(format($$select 1 from cancel_table(%L, '70000000-0000-0000-0000-000000000004', now())$$, tests.val('cashier')));
select is(tests.addon_stock(), 10, 'ยกเลิกซ้ำไม่คืนสต็อกซ้ำ');

-- สิทธิ์อ่านต้นทุน
select is(tests.device_a('select count(price) from addons'), '1', 'เครื่องอ่านราคาขายได้');
select is(tests.device_a('select cost from addons limit 1'), 'ERR:42501', 'เครื่องอ่านต้นทุน addon ไม่ได้');
select is(tests.device_a('select last_cost from ingredients limit 1'), 'ERR:42501', 'เครื่องอ่านต้นทุนวัตถุดิบไม่ได้');
select is(tests.device_a('select cost from bill_lines limit 1'), 'ERR:42501', 'เครื่องอ่านต้นทุนในบิลไม่ได้');
select is(tests.device_a('select count(*) from expenses'), '0', 'เครื่องไม่เห็นค่าใช้จ่าย');
select is(tests.device_a('select count(*) from fixed_costs'), '0', 'เครื่องไม่เห็นค่าคงที่');
select is(tests.owner_a('select count(*) from expenses'), '1', 'เจ้าของเห็นค่าใช้จ่าย');
select is(tests.owner_a($$with u as (update addons set cost = 2600 where id = '40000000-0000-0000-0000-000000000001' returning id) select count(*) from u$$), '1', 'เจ้าของแก้ต้นทุนได้');

create function tests.mgr_data(p_token text) returns text language sql as $$
  select format(
    $f$select jsonb_array_length(get_manager_data(%L, '2026-11-01', '2026-11-30', %L) -> 'expenses')$f$,
    tests.val('shop'), p_token
  )
$$;
select is(tests.owner_a(tests.mgr_data(null)), '1', 'เจ้าของอ่านข้อมูลรายงานได้');
select is(tests.owner_b(tests.mgr_data(null)), 'ERR:42501', 'เจ้าของร้านอื่นอ่านไม่ได้');
select is(tests.device_a(tests.mgr_data(null)), 'ERR:42501', 'เครื่องไม่มี token อ่านไม่ได้');
select is(tests.device_a(tests.mgr_data(tests.val('cashier'))), 'ERR:42501', 'แคชเชียร์อ่านข้อมูลรายงานไม่ได้');

-- สลับคนบนเครื่อง: session เก่าใช้ไม่ได้
select tests.set_val('manager', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000002', '2222') ->> 'session_token'$$));
select is(tests.device_a(tests.mgr_data(tests.val('manager'))), 'ERR:42501', 'ผู้จัดการที่ยังไม่ได้รับสิทธิ์เห็นต้นทุนอ่านข้อมูลรายงานไม่ได้');
update staff set can_view_costs = true where id = '10000000-0000-0000-0000-000000000002';
select is(tests.device_a(tests.mgr_data(tests.val('manager'))), '1', 'ผู้จัดการใช้ PIN อ่านข้อมูลรายงานได้');
select is(tests.device_a(tests.settle(tests.val('cashier'), '60000000-0000-0000-0000-000000000005', '70000000-0000-0000-0000-000000000005', 1, 0, 0, '{}', '50000000-0000-0000-0000-000000000001', 29900, 29900)), 'ERR:42501', 'สลับคนแล้ว session เก่าใช้ไม่ได้');
select is(tests.device_a(format($$select void_bill(%L, '60000000-0000-0000-0000-000000000003', 'ทดสอบ', now())$$, tests.val('manager'))), 'true', 'ผู้จัดการยกเลิกบิลของโต๊ะที่ปิดแล้วได้');

-- กะ
select is(tests.device_a(format($$select 1 from close_shift(%L, '90000000-0000-0000-0000-000000000000', 100000, now())$$, tests.val('manager'))), '1', 'ปิดกะแรกได้');
select is(tests.device_a(format($$select 1 from open_shift(%L, '90000000-0000-0000-0000-000000000001', 100000, now())$$, tests.val('manager'))), '1', 'เปิดกะได้');
select tests.device_a(format($$select 1 from open_shift(%L, '90000000-0000-0000-0000-000000000001', 100000, now())$$, tests.val('manager')));
select is((select count(*)::int from shifts where shop_id = tests.val('shop')::uuid), 2, 'เปิดกะซ้ำ id เดิมไม่บันทึกซ้ำ');
select is(tests.device_a(format($$select 1 from open_shift(%L, '90000000-0000-0000-0000-000000000002', 100000, now())$$, tests.val('manager'))), 'ERR:23505', 'เปิดสองกะพร้อมกันไม่ได้');
select is(tests.device_a(format($$select settle_bill(%L, '60000000-0000-0000-0000-000000000006', '70000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'before', 1, 0, 0, '{}', '50000000-0000-0000-0000-000000000001', 29900, 29900, now()) ->> 'shift_id'$$, tests.val('manager'))), '90000000-0000-0000-0000-000000000001', 'บิลผูกกับกะที่เปิดอยู่');
-- เลขใบเสร็จจากเครื่อง (ขายตอนออฟไลน์)
create function tests.settle_seq(p_bill text, p_session text, p_seq text) returns text language sql as $$
  select format(
    $f$select settle_bill(%L, %L, %L, '20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'before', 1, 0, 0, '{}', '50000000-0000-0000-0000-000000000001', 29900, 29900, now(), p_seq => %s) ->> 'no'$f$,
    tests.val('manager'), p_bill, p_session, p_seq
  )
$$;
select tests.set_val('seq', (select (receipt_seq + 5)::text from devices where shop_id = tests.val('shop')::uuid and revoked_at is null));
select is(tests.device_a(tests.settle_seq('60000000-0000-0000-0000-000000000007', '70000000-0000-0000-0000-000000000006', tests.val('seq'))),
  (select branch_code from shops where id = tests.val('shop')::uuid) || '-POS01-' || lpad(tests.val('seq'), 6, '0'), 'ใช้เลขใบเสร็จที่เครื่องส่งมา');
select is(tests.device_a(tests.settle_seq('60000000-0000-0000-0000-000000000008', '70000000-0000-0000-0000-000000000006', tests.val('seq'))), 'ERR:23505', 'เลขที่ใช้แล้วใช้ซ้ำไม่ได้');
select is(tests.device_a(tests.settle_seq('60000000-0000-0000-0000-000000000009', '70000000-0000-0000-0000-000000000006', 'null')),
  (select branch_code from shops where id = tests.val('shop')::uuid) || '-POS01-' || lpad((tests.val('seq')::int + 1)::text, 6, '0'), 'ไม่ส่งเลขมา server ออกต่อจากเลขล่าสุด');
select is(tests.device_a(format($$select 1 from close_shift(%L, '90000000-0000-0000-0000-000000000001', 129900, now())$$, tests.val('manager'))), '1', 'ปิดกะได้');
select is((select counted from shifts where id = '90000000-0000-0000-0000-000000000001'), 129900::bigint, 'บันทึกยอดนับเงิน');

-- token ออฟไลน์ (คำสั่งที่เข้าคิวตอนเน็ตหลุด)
select tests.set_val('offline', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000001', '1111') ->> 'offline_token'$$));
select isnt(tests.val('offline'), null, 'เข้าด้วย PIN แล้วได้ token ออฟไลน์');
select is((select count(*)::int from private.staff_offline_tokens where token_hash = tests.val('offline')), 0, 'ไม่เก็บ token ออฟไลน์ดิบ');
select tests.set_val('manager', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000002', '2222') ->> 'session_token'$$));
select is(tests.device_a(format($$select (get_day_entries(%L) ->> 'expenses') is not null$$, tests.val('offline'))), 'true', 'คนอื่นเข้าเครื่องแล้ว token ออฟไลน์ของแคชเชียร์ยังใช้ส่งคำสั่งได้');
select is(tests.owner_a('select count(*) from private.staff_offline_tokens'), 'ERR:42501', 'อ่านตาราง token ออฟไลน์ตรงไม่ได้');
update private.staff_offline_tokens set expires_at = now() - interval '1 second' where staff_id = '10000000-0000-0000-0000-000000000001';
select is(tests.device_a(format($$select (get_day_entries(%L) ->> 'expenses') is not null$$, tests.val('offline'))), 'ERR:42501', 'token ออฟไลน์หมดอายุ 7 วันแล้วใช้ไม่ได้');

-- หมดอายุ / เพิกถอน
select is(tests.device_a(format($$select 1 from end_staff_session(%L)$$, tests.val('manager'))), '1', 'ออกจาก session ได้');
select is(tests.device_a(tests.mgr_data(tests.val('manager'))), 'ERR:42501', 'ออกแล้ว token ใช้ไม่ได้');
select tests.set_val('manager', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000002', '2222') ->> 'session_token'$$));
update private.staff_sessions set expires_at = now() - interval '1 second' where staff_id = '10000000-0000-0000-0000-000000000002';
select is(tests.device_a(tests.mgr_data(tests.val('manager'))), 'ERR:42501', 'session หมดอายุใช้ไม่ได้');
select tests.set_val('manager', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000002', '2222') ->> 'session_token'$$));
update staff set active = false where id = '10000000-0000-0000-0000-000000000002';
select is(tests.device_a(tests.mgr_data(tests.val('manager'))), 'ERR:42501', 'พนักงานถูกปิดใช้งานแล้ว session ใช้ไม่ได้');
update staff set active = true where id = '10000000-0000-0000-0000-000000000002';
update devices set revoked_at = now() where shop_id = tests.val('shop')::uuid;
select is(tests.device_a(tests.mgr_data(tests.val('manager'))), 'ERR:42501', 'เครื่องถูกเพิกถอนแล้ว session ใช้ไม่ได้');

select * from finish();
rollback;
