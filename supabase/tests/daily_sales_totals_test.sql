-- รันด้วย: supabase test db
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(22);

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

create function tests.dst(p_col text, p_day date, p_token text) returns text language sql as $$
  select format(
    'select %s::text from get_daily_sales_totals(%L, %L, %L, %L) where business_date = %L',
    p_col, tests.val('shop'), '2026-11-01', '2026-11-05', p_token, p_day)
$$;
create function tests.nullcost(p_token text) returns text language sql as $$
  select format(
    'select count(*) filter (where addon_cost is null) from get_daily_sales_totals(%L, %L, %L, %L)',
    tests.val('shop'), '2026-11-01', '2026-11-05', p_token)
$$;

-- เจ้าของ: ช่วงเลือกเฉพาะวัน 1-5 พ.ย. ได้ 2 วัน (บิล 6 พ.ย. ไม่ถูกรวม)
select is(tests.owner_a(format('select count(*) from get_daily_sales_totals(%L, %L, %L)', tests.val('shop'), '2026-11-01', '2026-11-05')), '2', 'เจ้าของได้ 2 วันในช่วง');
select is(tests.owner_a(tests.dst('bills', '2026-11-01', null)), '2', 'วันที่ 1 นับบิลที่ไม่ยกเลิก 2 ใบ');
select is(tests.owner_a(tests.dst('a || chr(47) || c || chr(47) || f', '2026-11-01', null)), '3/1/1', 'รวมหัวคน a/c/f ไม่นับบิลยกเลิก');
select is(tests.owner_a(tests.dst('gross', '2026-11-01', null))::numeric, 40310::numeric, 'gross = sum(total)');
select is(tests.owner_a(tests.dst('net', '2026-11-01', null))::numeric, 38000::numeric, 'net = sum(total - vat)');
select is(tests.owner_a(tests.dst('buffet_net', '2026-11-01', null))::numeric, 27000::numeric, 'buffet_net = 20000*1.1 + 5000*1');
select is(tests.owner_a(tests.dst('addon_net', '2026-11-01', null))::numeric, 11000::numeric, 'addon_net = 2*5000*1.1');
select is(tests.owner_a(tests.dst('addon_cost', '2026-11-01', null))::numeric, 4000::numeric, 'เจ้าของเห็น addon_cost = 2*2000');
select is(tests.owner_a(tests.dst('bills', '2026-11-02', null)), '2', 'วันที่ 2 นับบิล subtotal=0 ด้วย');
select is(tests.owner_a(tests.dst('addon_net', '2026-11-02', null))::numeric, 0::numeric, 'subtotal=0 ได้ k2=0 ไม่หารศูนย์');
select is(tests.owner_a(tests.dst('addon_cost', '2026-11-02', null))::numeric, 30::numeric, 'addon_cost ไม่ขึ้นกับ k2');
select is(tests.owner_a(tests.dst('buffet_net', '2026-11-02', null))::numeric, 10000::numeric, 'buffet_net วันที่ 2');

-- เครื่อง/แคชเชียร์: ได้แถวแต่ addon_cost เป็น NULL
select is(tests.device_a(tests.nullcost(null)), '2', 'เครื่องไม่มี token ได้ addon_cost เป็น NULL');
select tests.set_val('cashier', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000001', '1111') ->> 'session_token'$$));
select is(tests.device_a(tests.nullcost(tests.val('cashier'))), '2', 'แคชเชียร์ได้ addon_cost เป็น NULL');
select is(tests.device_a(tests.dst('addon_net', '2026-11-01', tests.val('cashier')))::numeric, 11000::numeric, 'แคชเชียร์ยังเห็นยอดขาย');

-- ผู้จัดการ: ขึ้นกับ can_view_costs
select tests.set_val('manager', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000002', '2222') ->> 'session_token'$$));
select is(tests.device_a(tests.nullcost(tests.val('manager'))), '2', 'ผู้จัดการที่ไม่มีสิทธิ์ต้นทุนได้ NULL');
update staff set can_view_costs = true where id = '10000000-0000-0000-0000-000000000002';
select is(tests.device_a(tests.dst('addon_cost', '2026-11-01', tests.val('manager')))::numeric, 4000::numeric, 'ผู้จัดการที่มีสิทธิ์เห็น addon_cost');

-- ร้านอื่น
select is(tests.owner_b(tests.dst('bills', '2026-11-01', null)), 'ERR:42501', 'เจ้าของร้านอื่นอ่านไม่ได้');
select is(tests.device_b(tests.dst('bills', '2026-11-01', tests.val('manager'))), 'ERR:42501', 'token ของเครื่องอื่นใช้ไม่ได้');
select is(tests.device_b(tests.dst('bills', '2026-11-01', tests.val('token_b'))), 'ERR:42501', 'token ของร้านอื่นใช้อ่านร้านนี้ไม่ได้');

-- ช่วงวันที่ไม่ถูกต้อง
select is(tests.owner_a(format('select count(*) from get_daily_sales_totals(%L, %L, %L)', tests.val('shop'), '2026-11-05', '2026-11-01')), 'ERR:22023', 'from > to ถูกปฏิเสธ');
select is(tests.owner_a(format('select count(*) from get_daily_sales_totals(%L, %L, %L)', tests.val('shop'), '2026-01-01', '2027-12-31')), 'ERR:22023', 'ช่วงเกิน 400 วันถูกปฏิเสธ');

select * from finish();
rollback;
