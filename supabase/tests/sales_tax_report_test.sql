-- รันด้วย: supabase test db
-- get_sales_tax_report / get_daily_device_summary: รายงานภาษีขายรายเดือนและสรุปรายวันรายเครื่อง
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(23);

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

-- ข้อมูลทดสอบ (เดือน ก.พ. 2026): ขอบเดือน 2 ใบ, ใบที่ตัดรอบวัน 1 ใบ, ใบเสร็จ/ใบกำกับอย่างย่อที่ถูกแทนด้วยใบเต็มรูป
insert into bills (id, shop_id, device_id, no, business_date, at, subtotal, vat, total, method_type, received, rd_machine_code, is_tax_invoice)
select x.id::uuid, d.shop_id, d.id, x.no, x.bd::date, x.at::timestamptz, x.total, x.vat, x.total, 'cash', x.total, x.rd, x.tax
from devices d,
(values
  ('61000000-0000-0000-0000-000000000001', 'B-JAN', '2026-01-31', '2026-01-31 23:00+07', 100::bigint, 0::bigint, null, false),
  ('61000000-0000-0000-0000-000000000002', 'R-1',   '2026-02-01', '2026-02-01 10:00+07', 10700, 700, null, false),
  ('61000000-0000-0000-0000-000000000003', 'R-2',   '2026-02-01', '2026-02-01 11:00+07', 21400, 1400, 'RD-001', true),
  ('61000000-0000-0000-0000-000000000005', 'R-3',   '2026-02-02', '2026-02-02 09:00+07', 5350, 350, null, false),
  ('61000000-0000-0000-0000-000000000006', 'C-1',   '2026-02-28', '2026-03-01 00:30+07', 107, 7, null, false),
  ('61000000-0000-0000-0000-000000000007', 'M-MAR', '2026-03-01', '2026-03-01 10:00+07', 100, 0, null, false)
) as x(id, no, bd, at, total, vat, rd, tax)
where d.shop_id = tests.val('shop')::uuid;
-- R-2 ถูกยกเลิกและแทนด้วยใบกำกับเต็มรูป F-1
update bills set voided = true, void_reason = 'ออกใบกำกับภาษีเต็มรูปแทน', void_by = 'เจ้าของ', void_at = now() where id = '61000000-0000-0000-0000-000000000003';
insert into bills (id, shop_id, device_id, no, business_date, at, subtotal, vat, total, method_type, received, rd_machine_code, is_tax_invoice,
  replaces_bill_id, is_full_invoice, buyer_name, buyer_tax_id, buyer_branch, buyer_address)
select '61000000-0000-0000-0000-000000000004', d.shop_id, d.id, '00000-F-000001', '2026-02-01', '2026-02-01 12:00+07', 21400, 1400, 21400, 'cash', 21400, 'RD-001', true,
  '61000000-0000-0000-0000-000000000003', true, 'บริษัท ก', '0105500000001', '00000', 'กรุงเทพ'
from devices d where d.shop_id = tests.val('shop')::uuid;

create function tests.rep(p_month text) returns text language sql as $$
  select tests.owner_a(format($f$select count(*) from get_sales_tax_report(%L, %L)$f$, tests.val('shop'), p_month))
$$;

-- 1) รายงานภาษีขาย
select is(tests.rep('2026-02-01'), '5', 'เดือน ก.พ.: ตัดวันสุดท้ายของเดือนก่อน/วันแรกของเดือนถัดไปออก เหลือ 5 ใบ');
select is(tests.rep('2026-02-17'), '5', 'p_month เป็นวันไหนของเดือนก็ได้');
select is(tests.owner_a(format($f$select string_agg(no, ',' order by business_date, at, no) from get_sales_tax_report(%L, '2026-02-01')$f$, tests.val('shop'))),
  'R-1,R-2,00000-F-000001,R-3,C-1', 'เรียงตามวันที่ ตามเวลา ตามเลขที่; ใบหลังเที่ยงคืนแต่ก่อนตัดรอบวันอยู่ในวันที่ 28 ก.พ.');
select is(tests.owner_a(format($f$select string_agg(doc_type, ',' order by at) from get_sales_tax_report(%L, '2026-02-01')$f$, tests.val('shop'))),
  'receipt,abb,full,receipt,receipt', 'doc_type: receipt / abb / full');
select is(tests.owner_a(format($f$select concat_ws('|', voided, void_reason, replaces_no is null) from get_sales_tax_report(%L, '2026-02-01') where no = 'R-2'$f$, tests.val('shop'))),
  't|ออกใบกำกับภาษีเต็มรูปแทน|t', 'ใบที่ยกเลิกยังอยู่ในรายงานพร้อมเหตุผล');
select is(tests.owner_a(format($f$select concat_ws('|', replaces_no, buyer_name, buyer_tax_id, buyer_branch, rd_machine_code, device_code is not null) from get_sales_tax_report(%L, '2026-02-01') where no = '00000-F-000001'$f$, tests.val('shop'))),
  'R-2|บริษัท ก|0105500000001|00000|RD-001|t', 'ใบเต็มรูปมี replaces_no และข้อมูลผู้ซื้อ');
select is(tests.owner_a(format($f$select bool_and(base + vat = total)::text from get_sales_tax_report(%L, '2026-02-01')$f$, tests.val('shop'))),
  'true', 'base + vat = total ทุกแถว');
select is(tests.owner_a(format($f$select concat_ws('|', base, vat, total) from get_sales_tax_report(%L, '2026-02-01') where no = 'R-1'$f$, tests.val('shop'))),
  '10000|700|10700', 'ยอดเป็นสตางค์แบบตรงตัว: base 10000 vat 700 total 10700');

-- 2) สรุปรายวันรายเครื่อง
create function tests.sum_row(p_dev text, p_day text) returns text language sql as $$
  select tests.owner_a(format($f$select concat_ws('|', first_no, last_no, bills, voided, base, vat, total) from get_daily_device_summary(%L, '2026-02-01', '2026-02-28')
    where business_date = %L and device_code %s$f$, tests.val('shop'), p_day, p_dev))
$$;
select is(tests.sum_row('<> ''FULL''', '2026-02-01'), 'R-1|R-2|1|1|10000|700|10700', 'สรุปเครื่อง 1 ก.พ.: เลขแรก/สุดท้าย นับใบ ยกเลิก 1 ใบ ผลรวมไม่นับที่ยกเลิก');
select is(tests.sum_row('= ''FULL''', '2026-02-01'), '00000-F-000001|00000-F-000001|1|0|20000|1400|21400', 'ใบกำกับเต็มรูปแยกเป็นแถว FULL');
select is(tests.sum_row('<> ''FULL''', '2026-02-02'), 'R-3|R-3|1|0|5000|350|5350', 'สรุปวันที่ 2 ก.พ.');
select is(tests.owner_a(format($f$select count(*) from get_daily_device_summary(%L, '2026-01-31', '2026-03-01')$f$, tests.val('shop'))),
  '6', 'ช่วง 31 ม.ค.-1 มี.ค. ได้ 6 แถว (31 ม.ค., 1 ก.พ. x2, 2 ก.พ., 28 ก.พ., 1 มี.ค.)');
select is(tests.owner_a(format($f$select rd_machine_code from get_daily_device_summary(%L, '2026-02-01', '2026-02-01') where device_code = 'FULL'$f$, tests.val('shop'))),
  'RD-001', 'แถวสรุปมีรหัสเครื่อง POS');

-- 3) สิทธิ์
select tests.set_val('cashier', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000001', '1111') ->> 'session_token'$$));
select is(tests.device_a(format($$select count(*) from get_sales_tax_report(%L, '2026-02-01', %L)$$, tests.val('shop'), tests.val('cashier'))),
  'ERR:42501', 'แคชเชียร์ดูรายงานภาษีขายไม่ได้');
select is(tests.device_a(format($$select count(*) from get_daily_device_summary(%L, '2026-02-01', '2026-02-28', %L)$$, tests.val('shop'), tests.val('cashier'))),
  'ERR:42501', 'แคชเชียร์ดูสรุปรายวันไม่ได้');
select is(tests.device_a(format($$select count(*) from get_sales_tax_report(%L, '2026-02-01')$$, tests.val('shop'))),
  'ERR:42501', 'เครื่องที่ไม่มีโทเคนดูรายงานไม่ได้');
select is(tests.device_a(format($$select count(*) from get_daily_device_summary(%L, '2026-02-01', '2026-02-28')$$, tests.val('shop'))),
  'ERR:42501', 'เครื่องที่ไม่มีโทเคนดูสรุปรายวันไม่ได้');
select is(tests.owner_b(format($$select count(*) from get_sales_tax_report(%L, '2026-02-01')$$, tests.val('shop'))),
  'ERR:42501', 'เจ้าของร้านอื่นดูรายงานไม่ได้');
select tests.set_val('manager', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000002', '2222') ->> 'session_token'$$));
select is(tests.device_a(format($$select count(*) from get_sales_tax_report(%L, '2026-02-01', %L)$$, tests.val('shop'), tests.val('manager'))),
  '5', 'ผู้จัดการดูรายงานได้');
select is(tests.device_a(format($$select count(*) from get_daily_device_summary(%L, '2026-02-01', '2026-02-28', %L)$$, tests.val('shop'), tests.val('manager'))),
  '4', 'ผู้จัดการดูสรุปรายวันได้');

-- 4) ช่วงวันที่ไม่ถูกต้อง
select is(tests.owner_a(format($$select count(*) from get_daily_device_summary(%L, '2026-02-10', '2026-02-01')$$, tests.val('shop'))),
  'ERR:22023', 'from > to ถูกปฏิเสธ');
select is(tests.owner_a(format($$select count(*) from get_daily_device_summary(%L, '2024-01-01', '2026-02-01')$$, tests.val('shop'))),
  'ERR:22023', 'ช่วงเกิน 400 วันถูกปฏิเสธ');
select is(tests.owner_a(format($$select count(*) from get_sales_tax_report(%L, null)$$, tests.val('shop'))),
  'ERR:22023', 'p_month เป็น null ถูกปฏิเสธ');

select * from finish();
rollback;
