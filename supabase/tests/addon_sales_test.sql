-- รันด้วย: supabase test db
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(15);

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
select tests.set_val('token_b', tests.device_b($$select verify_staff_pin('10000000-0000-0000-0000-000000000003', '3333') ->> 'session_token'$$));

-- บิลทดสอบ (เพิ่มตรงด้วยสิทธิ์ superuser)
-- 1 พ.ย.: บิล 1 subtotal 30000 + service 3000 + vat 2310 = 35310 -> net 33000, k2 = 1.1
--         บิล 2 subtotal = total ไม่มี vat -> k2 = 1 ; บิลยกเลิกต้องไม่ถูกนับ
-- 2 พ.ย.: บิล subtotal 0 -> k2 = 0 ; บิลปกติ 10000 ; 6 พ.ย. อยู่นอกช่วง
insert into bills (id, shop_id, device_id, no, business_date, at, subtotal, service, vat, total,
                   heads_a, heads_c, heads_f, method_type, received, voided, void_reason, void_by, void_at)
select v.id::uuid, d.shop_id, d.id, v.no, v.bd::date, now(), v.sub, v.svc, v.vat, v.tot,
       v.ha, v.hc, v.hf, 'cash', v.tot, v.vd, case when v.vd then 'x' end, case when v.vd then 'x' end,
       case when v.vd then now() end
from devices d,
(values
  ('a0000000-0000-0000-0000-000000000001', 'T-1', '2026-11-01', 30000, 3000, 2310, 35310, 2, 1, 0, false),
  ('a0000000-0000-0000-0000-000000000002', 'T-2', '2026-11-01', 5000, 0, 0, 5000, 1, 0, 1, false),
  ('a0000000-0000-0000-0000-000000000003', 'T-3', '2026-11-01', 9999, 0, 0, 9999, 9, 9, 9, true),
  ('a0000000-0000-0000-0000-000000000004', 'T-4', '2026-11-02', 0, 0, 0, 0, 0, 0, 0, false),
  ('a0000000-0000-0000-0000-000000000005', 'T-5', '2026-11-02', 10000, 0, 0, 10000, 3, 2, 1, false),
  ('a0000000-0000-0000-0000-000000000006', 'T-6', '2026-11-06', 7000, 0, 0, 7000, 1, 0, 0, false)
) as v(id, no, bd, sub, svc, vat, tot, ha, hc, hf, vd)
where d.shop_id = tests.val('shop')::uuid;
insert into bill_lines (shop_id, bill_id, line_no, type, name, qty, price, cost)
select tests.val('shop')::uuid, v.bill::uuid, v.n, v.t, 'x', v.q, v.p, v.c
from (values
  ('a0000000-0000-0000-0000-000000000001', 1, 'buffet', 2, 10000, null::bigint),
  ('a0000000-0000-0000-0000-000000000001', 2, 'addon', 2, 5000, 2000),
  ('a0000000-0000-0000-0000-000000000002', 1, 'buffet', 1, 5000, null),
  ('a0000000-0000-0000-0000-000000000003', 1, 'addon', 1, 9999, 5000),
  ('a0000000-0000-0000-0000-000000000004', 1, 'addon', 1, 100, 30),
  ('a0000000-0000-0000-0000-000000000005', 1, 'buffet', 1, 10000, null),
  ('a0000000-0000-0000-0000-000000000006', 1, 'addon', 1, 7000, 1000)
) as v(bill, n, t, q, p, c);


set local session_replication_role = replica; -- ข้าม trigger immutable เฉพาะตอนเตรียมข้อมูล
insert into bank_accounts (id, shop_id, bank_name, account_no) values
  ('b0000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'KBank', '111'),
  ('b0000000-0000-0000-0000-000000000002', tests.val('shop')::uuid, 'SCB', '222');
update bills set bank_account_id = 'b0000000-0000-0000-0000-000000000001'
  where id = 'a0000000-0000-0000-0000-000000000006';

create function tests.addon(p_col text, p_name text, p_token text) returns text language sql as $$
  select format(
    'select %s::text from get_addon_sales(%L, %L, %L, %L) where name = %L',
    p_col, tests.val('shop'), '2026-11-01', '2026-11-05', p_token, p_name)
$$;
create function tests.addon_all(p_token text) returns text language sql as $$
  select format('select count(*) filter (where cost is null) || %L || count(*) from get_addon_sales(%L, %L, %L, %L)',
    '/', tests.val('shop'), '2026-11-01', '2026-11-05', p_token)
$$;

-- ปรับชื่อสินค้าให้แยกได้: บิล 1 = น้ำ (2 x 5000, cost 2000), บิล 4 = ขนม (1 x 100, cost 30)
-- บิล 3 (ยกเลิก) ชื่อ 'น้ำ' ต้องไม่ถูกนับ ; บิล 6 (6 พ.ย.) อยู่นอกช่วง
update bill_lines set name = 'น้ำ' where bill_id in ('a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000003') and type = 'addon';
update bill_lines set name = 'ขนม' where bill_id = 'a0000000-0000-0000-0000-000000000004';
update bill_lines set name = 'น้ำ' where bill_id = 'a0000000-0000-0000-0000-000000000006';
set local session_replication_role = origin;

select is(tests.owner_a(tests.addon('qty', 'น้ำ', null)), '2', 'น้ำ qty = 2 ไม่นับบิลยกเลิกและนอกช่วง');
select is(tests.owner_a(tests.addon('rev', 'น้ำ', null))::numeric, 10000::numeric, 'น้ำ rev = 2*5000 (ไม่คูณ k2)');
select is(tests.owner_a(tests.addon('cost', 'น้ำ', null))::numeric, 4000::numeric, 'เจ้าของเห็น cost = 2*2000');
select is(tests.owner_a(tests.addon('rev', 'ขนม', null))::numeric, 100::numeric, 'ขนม rev = 100');
select is(tests.owner_a(tests.addon_all(null)), '0/2', 'มี 2 ชื่อ เจ้าของไม่มี cost NULL');

select is(tests.device_a(tests.addon_all(null)), '2/2', 'เครื่องไม่มี token ได้ cost NULL');
select tests.set_val('cashier', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000001', '1111') ->> 'session_token'$$));
select is(tests.device_a(tests.addon_all(tests.val('cashier'))), '2/2', 'แคชเชียร์ได้ cost NULL');
select is(tests.device_a(tests.addon('rev', 'น้ำ', tests.val('cashier')))::numeric, 10000::numeric, 'แคชเชียร์ยังเห็น rev');
select tests.set_val('manager', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000002', '2222') ->> 'session_token'$$));
select is(tests.device_a(tests.addon_all(tests.val('manager'))), '2/2', 'ผู้จัดการไม่มีสิทธิ์ต้นทุนได้ NULL');
update staff set can_view_costs = true where id = '10000000-0000-0000-0000-000000000002';
select is(tests.device_a(tests.addon('cost', 'น้ำ', tests.val('manager')))::numeric, 4000::numeric, 'ผู้จัดการที่มีสิทธิ์เห็น cost');

select is(tests.owner_b(tests.addon('qty', 'น้ำ', null)), 'ERR:42501', 'เจ้าของร้านอื่นอ่านไม่ได้');
select is(tests.device_b(tests.addon('qty', 'น้ำ', tests.val('token_b'))), 'ERR:42501', 'token ร้านอื่นอ่านร้านนี้ไม่ได้');
select is(tests.owner_a(format('select count(*) from get_addon_sales(%L, %L, %L)', tests.val('shop'), '2026-11-05', '2026-11-01')), 'ERR:22023', 'from > to ถูกปฏิเสธ');

-- ลบบัญชีธนาคาร: ที่ถูกใช้ในบิลต้องล้มเหลว (23503) แม้บิลไม่ได้โหลดในแอป ; ที่ไม่ถูกใช้ลบได้
select is(tests.owner_a($$delete from bank_accounts where id = 'b0000000-0000-0000-0000-000000000001' returning 'x'$$), 'ERR:23503', 'ลบบัญชีที่มีบิลใช้อยู่ไม่ได้');
select is(tests.owner_a($$delete from bank_accounts where id = 'b0000000-0000-0000-0000-000000000002' returning 'x'$$), 'x', 'ลบบัญชีที่ไม่มีบิลใช้ได้');

select * from finish();
rollback;
