-- รันด้วย: supabase test db
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(14);

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
  ('10000000-0000-0000-0000-000000000003', tests.val('shop_b')::uuid, 'แคชเชียร์ B', 'cashier');
select set_staff_pin_row.* from (
  select tests.owner_a($$select 1 from set_staff_pin('10000000-0000-0000-0000-000000000001', '1111')$$),
         tests.owner_b($$select 1 from set_staff_pin('10000000-0000-0000-0000-000000000003', '3333')$$)
) set_staff_pin_row;

insert into dining_tables (id, shop_id, name, seats) values
  ('20000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'โต๊ะ 1', 4);
insert into packages (id, shop_id, name, adult_price, child_price, time_limit_min) values
  ('30000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'บุฟเฟต์', 29900, 14900, 120);

select tests.set_val('cashier', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000001', '1111') ->> 'session_token'$$));
select tests.set_val('token_b', tests.device_b($$select verify_staff_pin('10000000-0000-0000-0000-000000000003', '3333') ->> 'session_token'$$));

create function tests.round(p_token text, p_round text, p_session text) returns text language sql as $f$
  select tests.device_a(format($$select 1 from send_round(%L, %L, %L, '20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'after', 1, 0, 0, '{}', now())$$,
    p_token, p_round, p_session))
$f$;

-- เครื่องแรกเปิดโต๊ะ 1 ด้วย session S1
select is(tests.round(tests.val('cashier'), '80000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001'), '1', 'เครื่องแรกเปิดโต๊ะได้');
-- เครื่องที่สองเปิดโต๊ะเดียวกันด้วย session S2 ต่างกัน
select is(tests.round(tests.val('cashier'), '80000000-0000-0000-0000-000000000002', '70000000-0000-0000-0000-000000000002'), '1', 'session id ที่สองไม่ error');
select is((select count(*)::int from table_sessions where table_id = '20000000-0000-0000-0000-000000000001'), 1, 'มีรอบเปิดอยู่รอบเดียว');
select is((select count(*)::int from table_rounds where session_id = '70000000-0000-0000-0000-000000000001'), 2, 'รอบสั่งของทั้งสองเครื่องอยู่ในรอบเดียว');
select is((select session_id::text from table_session_aliases where alias_id = '70000000-0000-0000-0000-000000000002'), '70000000-0000-0000-0000-000000000001', 'บันทึก alias ชี้ไปรอบแรก');

-- คำสั่งที่ค้างในคิวด้วย alias id ยังลงรอบที่รวมแล้ว
select is(tests.round(tests.val('cashier'), '80000000-0000-0000-0000-000000000003', '70000000-0000-0000-0000-000000000002'), '1', 'ส่งรอบด้วย alias id ได้');
select is((select count(*)::int from table_rounds where session_id = '70000000-0000-0000-0000-000000000001'), 3, 'alias id ลงรอบที่รวมแล้ว');

-- adjust_sent / set_table_notes / close_table ด้วย alias id (ผู้จัดการลดรายการได้)
insert into staff (id, shop_id, name, role) values
  ('10000000-0000-0000-0000-000000000002', tests.val('shop')::uuid, 'ผู้จัดการ A', 'manager');
select tests.owner_a($$select 1 from set_staff_pin('10000000-0000-0000-0000-000000000002', '2222')$$);
select tests.set_val('manager', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000002', '2222') ->> 'session_token'$$));
select is(tests.device_a(format($$select adjust_sent(%L, '81000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000002', 'head', 'a', 1, 'x', now())$$, tests.val('manager'))), 'true', 'adjust_sent ด้วย alias id ลงรอบที่รวม');
select tests.set_val('cashier', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000001', '1111') ->> 'session_token'$$));
select is(tests.device_a(format($$select set_table_notes(%L, '70000000-0000-0000-0000-000000000002', 'ไม่ใส่ผัก')$$, tests.val('cashier'))), 'true', 'set_table_notes ด้วย alias id');
select tests.device_a(format($$select 1 from send_round(%L, '80000000-0000-0000-0000-000000000009', '70000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'after', 0, 0, 0, '{}', now())$$, tests.val('cashier')));
select is(tests.device_a(format($$select 1 from close_table(%L, '70000000-0000-0000-0000-000000000002', now())$$, tests.val('cashier'))), 'ERR:22023', 'close_table ด้วย alias id เห็นยอดค้างของรอบที่รวม');

-- ยกเลิกโต๊ะด้วย alias id ถูกปฏิเสธ และรอบที่รวมยังเปิดอยู่
select is(tests.device_a(format($$select 1 from cancel_table(%L, '70000000-0000-0000-0000-000000000002', now())$$, tests.val('cashier'))), 'ERR:22023', 'cancel_table ด้วย alias id ถูกปฏิเสธ');
select ok((select closed_at is null from table_sessions where id = '70000000-0000-0000-0000-000000000001'), 'รอบที่รวมยังเปิดอยู่หลังปฏิเสธ');

-- ร้านอื่นใช้ alias ไม่ได้ (ไม่เห็นรอบ/alias ของร้าน A)
select is(tests.owner_b($$select count(*) from table_session_aliases$$), '0', 'ร้านอื่นอ่าน alias ไม่ได้');

-- ปิดรอบที่รวมแล้ว alias ใช้ต่อไม่ได้
update table_sessions set closed_at = now() where id = '70000000-0000-0000-0000-000000000001';
select is(tests.round(tests.val('cashier'), '80000000-0000-0000-0000-000000000004', '70000000-0000-0000-0000-000000000002'), 'ERR:22023', 'รอบที่รวมปิดแล้ว alias ส่งรอบไม่ได้');

select * from finish();
rollback;
