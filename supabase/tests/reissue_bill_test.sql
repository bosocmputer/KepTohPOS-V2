-- รันด้วย: supabase test db
-- reissue_bill: ออกบิลใหม่แทนบิลเดิมในเดือนภาษีเดียวกัน
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(19);


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

insert into staff (id, shop_id, name, role) values
  ('10000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'แคชเชียร์ A', 'cashier'),
  ('10000000-0000-0000-0000-000000000002', tests.val('shop')::uuid, 'ผู้จัดการ A', 'manager');
select tests.owner_a($$select 1 from set_staff_pin('10000000-0000-0000-0000-000000000001', '1111')$$);
select tests.owner_a($$select 1 from set_staff_pin('10000000-0000-0000-0000-000000000002', '2222')$$);
insert into dining_tables (id, shop_id, name, seats) values
  ('20000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'โต๊ะ 1', 4);
insert into packages (id, shop_id, name, adult_price, child_price, time_limit_min) values
  ('30000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'บุฟเฟต์', 10000, 5000, 120);
insert into addons (id, shop_id, name, price, cost, stock) values
  ('40000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'น้ำ', 5000, 2000, 10);
insert into payment_methods (id, shop_id, name, type) values
  ('50000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'เงินสดหลัก', 'cash'),
  ('50000000-0000-0000-0000-000000000002', tests.val('shop')::uuid, 'โอน', 'transfer');
insert into bank_accounts (id, shop_id, bank_name, account_no) values
  ('80000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'ธนาคาร A', '111'),
  ('80000000-0000-0000-0000-000000000002', tests.val('shop_b')::uuid, 'ธนาคาร B', '222');
-- หนึ่งเครื่องมี session เดียว: ใช้โทเคนผู้จัดการขายก่อน แล้วค่อยสลับเป็นแคชเชียร์/ผู้จัดการตอนทดสอบสิทธิ์
select tests.set_val('tok', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000002', '2222') ->> 'session_token'$$));
select tests.device_a(format($$select 1 from open_shift(%L, '90000000-0000-0000-0000-000000000000', 0, now())$$, tests.val('tok')));

-- ขาย 1 ผู้ใหญ่ + น้ำ 2 ขวด (subtotal 20000) เลขบิล p_n
create function tests.sell(p_n int) returns text language plpgsql as $$
declare
  v_total bigint := (private.calc_bill_amounts(20000, (select service_pct from shops where id = tests.val('shop')::uuid),
    (select vat_mode from shops where id = tests.val('shop')::uuid), (select vat_rate from shops where id = tests.val('shop')::uuid),
    (select rounding from shops where id = tests.val('shop')::uuid))).total;
begin
  return tests.device_a(format(
    $f$select settle_bill(%L, %L, %L, '20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'before', 1, 0, 0, '{"40000000-0000-0000-0000-000000000001": 2}', '50000000-0000-0000-0000-000000000001', 1000000, %s, now()) ->> 'no'$f$,
    tests.val('tok'),
    format('60000000-0000-0000-0000-00000000000%s', p_n),
    format('70000000-0000-0000-0000-00000000000%s', p_n),
    v_total));
end $$;
create function tests.reissue(p_old int, p_new int, p_reason text, p_method uuid default null, p_bank uuid default null) returns text language sql as $$
  select tests.owner_a(format($f$select reissue_bill(%L, %L, %L, %L, %L, %L) ->> 'no'$f$, tests.val('shop'),
    format('60000000-0000-0000-0000-00000000000%s', p_old), format('61000000-0000-0000-0000-00000000000%s', p_new), p_reason, p_method, p_bank))
$$;
create function tests.bid(p_n int) returns uuid language sql as $$ select format('60000000-0000-0000-0000-00000000000%s', p_n)::uuid $$;
create function tests.nid(p_n int) returns uuid language sql as $$ select format('61000000-0000-0000-0000-00000000000%s', p_n)::uuid $$;

-- เตรียม: บิล 1,2,3,4 ในเดือนนี้ (สต็อกน้ำเหลือ 2) + บิลเดือนก่อน
select tests.set_val('no1', tests.sell(1));
select tests.sell(2);
select tests.sell(3);
select tests.sell(4);
insert into bills (id, shop_id, device_id, no, business_date, at, subtotal, total, method_type, received)
select tests.bid(5), d.shop_id, d.id, 'OLD-1', date_trunc('month', now() at time zone 'Asia/Bangkok')::date - 1, now(), 100, 100, 'cash', 100
from devices d where d.shop_id = tests.val('shop')::uuid;

-- 1) เจ้าของออกบิลใหม่แทนบิล 1
select tests.set_val('no_new1', tests.reissue(1, 1, 'พิมพ์ผิด'));
select isnt(tests.val('no_new1'), tests.val('no1'), 'เลขบิลใหม่ไม่ซ้ำเลขเดิม');
select is((select void_reason from bills where id = tests.bid(1)), 'ออกใบใหม่แทน: พิมพ์ผิด', 'บิลเดิมถูกยกเลิกพร้อมเหตุผล');
select is((select replaces_bill_id from bills where id = tests.nid(1)), tests.bid(1), 'บิลใหม่ชี้ replaces_bill_id ไปบิลเดิม');
select is(
  (select (n.subtotal, n.service, n.vat, n.rounding, n.total, n.heads_a, n.method_type) = (o.subtotal, o.service, o.vat, o.rounding, o.total, o.heads_a, o.method_type)
   from bills n, bills o where n.id = tests.nid(1) and o.id = tests.bid(1)),
  true, 'ยอดเงินบิลใหม่เท่าบิลเดิม');
select is(
  (select string_agg(concat_ws('|', l.line_no, l.type, l.name, l.qty, l.price, l.cost), ';' order by l.line_no) from bill_lines l where l.bill_id = tests.nid(1)),
  (select string_agg(concat_ws('|', l.line_no, l.type, l.name, l.qty, l.price, l.cost), ';' order by l.line_no) from bill_lines l where l.bill_id = tests.bid(1)),
  'รายการในบิลใหม่ copy จากบิลเดิม');
select is((select stock from addons where id = '40000000-0000-0000-0000-000000000001'), 2, 'สต็อกไม่เปลี่ยนจากการออกบิลใหม่');

-- 2) เปลี่ยนวิธีชำระ
select tests.reissue(2, 2, 'ลูกค้าเปลี่ยนเป็นโอน', '50000000-0000-0000-0000-000000000002', '80000000-0000-0000-0000-000000000001');
select is((select method_type || '/' || received::text || '/' || total::text from bills where id = tests.nid(2)),
  'transfer/' || (select total from bills where id = tests.bid(2)) || '/' || (select total from bills where id = tests.bid(2)), 'เปลี่ยนวิธีชำระเป็นโอน received = total');
select is((select bank_account_info from bills where id = tests.nid(2)), 'ธนาคาร A · 111', 'บันทึกบัญชีธนาคารที่เลือก');
select is(tests.reissue(3, 3, 'x', '50000000-0000-0000-0000-000000000099'), 'ERR:22023', 'วิธีชำระที่ไม่มีในร้านถูกปฏิเสธ');
select is(tests.reissue(3, 3, 'x', '50000000-0000-0000-0000-000000000002'), 'ERR:22023', 'โอนโดยไม่ระบุบัญชีธนาคารถูกปฏิเสธ');
select is(tests.reissue(3, 3, 'x', '50000000-0000-0000-0000-000000000002', '80000000-0000-0000-0000-000000000002'), 'ERR:22023', 'บัญชีธนาคารของร้านอื่นถูกปฏิเสธ');

-- 3) สิทธิ์
select tests.set_val('cashier', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000001', '1111') ->> 'session_token'$$));
select is(tests.device_a(format($$select reissue_bill(%L, %L, %L, 'x', null, null, %L) ->> 'no'$$, tests.val('shop'), tests.bid(3), tests.nid(3), tests.val('cashier'))),
  'ERR:42501', 'แคชเชียร์ออกบิลใหม่ไม่ได้');
select is(tests.owner_b(format($$select reissue_bill(%L, %L, %L, 'x') ->> 'no'$$, tests.val('shop'), tests.bid(3), tests.nid(3))),
  'ERR:42501', 'เจ้าของร้านอื่นออกบิลใหม่ไม่ได้');
select tests.set_val('manager', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000002', '2222') ->> 'session_token'$$));
select isnt(tests.device_a(format($$select reissue_bill(%L, %L, %L, 'x', null, null, %L) ->> 'no'$$, tests.val('shop'), tests.bid(3), tests.nid(3), tests.val('manager'))),
  'ERR:42501', 'ผู้จัดการออกบิลใหม่ได้');

-- 4) กฎอื่น
select is(tests.reissue(1, 6, 'อีกที'), 'ERR:22023', 'บิลที่ยกเลิกแล้วออกใหม่ไม่ได้');
select is(tests.reissue(5, 7, 'ข้ามเดือน'), 'ERR:22023', 'บิลเดือนก่อนออกใหม่ไม่ได้');
select is(tests.reissue(1, 8, 'ซ้ำ'), 'ERR:22023', 'ออกใหม่แทนบิลเดิมซ้ำไม่ได้');
select is(tests.reissue(1, 1, 'ส่งซ้ำ'), tests.val('no_new1'), 'p_new_id เดิม ส่งซ้ำได้บิลเดิมกลับ');
select throws_ok(format($$update bills set replaces_bill_id = %L where id = %L$$, tests.bid(4), tests.nid(2)), 'P0001', null, 'แก้ replaces_bill_id หลังสร้างไม่ได้ (trigger)');

select * from finish();
rollback;
