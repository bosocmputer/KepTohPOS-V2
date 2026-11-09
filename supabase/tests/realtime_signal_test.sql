-- รันด้วย: supabase test db
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(8);

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
insert into ctx select 'shop_a', tests.owner_a($$select create_organization_with_shop('กิจการ A', 'ร้าน A')$$);
insert into ctx select 'shop_b', tests.owner_b($$select create_organization_with_shop('กิจการ B', 'ร้าน B')$$);
insert into ctx select 'pair_a', tests.owner_a(format($$select pairing_code from create_device_pairing(%L, 'เครื่อง A')$$, (select val from ctx where key = 'shop_a')));
select tests.device_a(format($$select shop_id from claim_device(%L)$$, (select val from ctx where key = 'pair_a')));
create function tests.shop_a() returns uuid language sql as $$ select val::uuid from ctx where key = 'shop_a' $$;
create function tests.shop_b() returns uuid language sql as $$ select val::uuid from ctx where key = 'shop_b' $$;

-- ฟังข้อความบน topic ที่ขอ ในบทบาทที่กำหนด
create function tests.visible(p_role_fn text, p_topic text) returns text language plpgsql as $$
declare r text;
begin
  perform set_config('realtime.topic', p_topic, true);
  r := tests.q('authenticated',
    case p_role_fn when 'owner_a' then '00000000-0000-0000-0000-00000000000a'
                   when 'owner_b' then '00000000-0000-0000-0000-00000000000b'
                   else '00000000-0000-0000-0000-00000000000d' end::uuid,
    p_role_fn = 'device_a',
    $q$select count(*) from realtime.messages where extension = 'broadcast'$q$);
  return r;
end;
$$;

-- ล้างข้อความที่ทริกเกอร์ของการสร้างร้าน/จับคู่ (ถ้ามี) แล้วทดสอบจากศูนย์
delete from realtime.messages;
insert into bills (id, shop_id, device_id, no, business_date, at, subtotal, total, method_type, received)
select gen_random_uuid(), d.shop_id, d.id, '00000-' || d.code || '-000001', current_date, now(), 100, 100, 'cash', 100
from devices d where d.shop_id = tests.shop_a();

select is(
  (select count(*)::int from realtime.messages
   where topic = 'shop:' || tests.shop_a() and event = 'changed' and private),
  1, 'เพิ่มบิลแล้วทริกเกอร์ส่งสัญญาณ 1 ครั้งบน topic ของร้าน');
select is(
  (select payload - 'id' from realtime.messages where topic = 'shop:' || tests.shop_a() limit 1),
  '{"table": "bills"}'::jsonb, 'payload มีแค่ชื่อตาราง ไม่มีข้อมูลแถว');
select is(
  (select count(*)::int from realtime.messages where topic = 'shop:' || tests.shop_b()),
  0, 'ร้านอื่นไม่ได้รับสัญญาณ');

update bills set voided = true, void_reason = 'test', void_by = 'test', void_at = now() where shop_id = tests.shop_a();
select is(
  (select count(*)::int from realtime.messages where topic = 'shop:' || tests.shop_a()),
  2, 'แก้ไขบิลก็ส่งสัญญาณ');

-- policy: อ่านได้เฉพาะ topic ของร้านที่ตัวเองอ่านได้
select is(tests.visible('owner_a', 'shop:' || tests.shop_a()), '2', 'เจ้าของ A เห็นสัญญาณ topic ร้าน A');
select is(tests.visible('device_a', 'shop:' || tests.shop_a()), '2', 'เครื่อง A (anonymous JWT) เห็นสัญญาณ topic ร้าน A');
select is(tests.visible('owner_b', 'shop:' || tests.shop_a()), '0', 'เจ้าของ B ไม่เห็น topic ร้าน A');
select is(
  tests.owner_a($$insert into realtime.messages (topic, extension, event, private) values ('shop:x', 'broadcast', 'changed', true) returning 'ok'$$),
  'ERR:42501', 'client ส่ง broadcast เองไม่ได้');

select * from finish();
rollback;
