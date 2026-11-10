-- รันด้วย: supabase test db
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(65);

-- รัน SQL ในบทบาท + ผู้ใช้ที่กำหนด แล้วคืนผลเป็น text หรือ ERR:<sqlstate>
-- กลับมาเป็น postgres ก่อนคืนค่า เพราะตารางภายในของ pgTAP ใช้ไม่ได้จากบทบาทอื่น
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
create function tests.outsider(p_sql text) returns text language sql as
  $$ select tests.q('authenticated', '00000000-0000-0000-0000-00000000000c', false, p_sql) $$;
create function tests.device_a(p_sql text) returns text language sql as
  $$ select tests.q('authenticated', '00000000-0000-0000-0000-00000000000d', true, p_sql) $$;
create function tests.device_b(p_sql text) returns text language sql as
  $$ select tests.q('authenticated', '00000000-0000-0000-0000-00000000000e', true, p_sql) $$;
create function tests.public_anon(p_sql text) returns text language sql as
  $$ select tests.q('anon', null, false, p_sql) $$;

insert into auth.users (id, email, is_anonymous) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.test', false),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.test', false),
  ('00000000-0000-0000-0000-00000000000c', 'c@example.test', false),
  ('00000000-0000-0000-0000-00000000000d', null, true),
  ('00000000-0000-0000-0000-00000000000e', null, true);

create temp table ctx (key text primary key, val text);

-- สมัครร้าน + แม่แบบ
insert into ctx select 'shop_a', tests.owner_a($$select create_organization_with_shop('กิจการ A', 'ร้าน A')$$);
insert into ctx select 'shop_b', tests.owner_b($$select create_organization_with_shop('กิจการ B', 'ร้าน B')$$);
create function tests.shop_a() returns uuid language sql as $$ select val::uuid from ctx where key = 'shop_a' $$;
create function tests.shop_b() returns uuid language sql as $$ select val::uuid from ctx where key = 'shop_b' $$;

select is(tests.device_a($$select create_organization_with_shop('x', 'y')$$), 'ERR:42501', 'บัญชีเครื่อง (anonymous) สมัครร้านไม่ได้');
select is(tests.public_anon($$select create_organization_with_shop('x', 'y')$$), 'ERR:42501', 'anon key อย่างเดียวสมัครร้านไม่ได้');
select is((select count(*)::int from categories where shop_id = tests.shop_a()), 10, 'แม่แบบ: หมวด 10 รายการ');
select is((select count(*)::int from expense_types where shop_id = tests.shop_a()), 7, 'แม่แบบ: ค่าใช้จ่ายรายวัน 7 รายการ');
select is((select count(*)::int from fixed_costs where shop_id = tests.shop_a() and amount = 0 and not active), 6, 'แม่แบบ: ค่าคงที่ 6 รายการ ยอด 0 ปิดไว้');
select is((select count(*)::int from void_reasons where shop_id = tests.shop_a()), 5, 'แม่แบบ: เหตุผลยกเลิก 5 รายการ');
select is((select count(*)::int from payment_methods where shop_id = tests.shop_a() and active), 2, 'แม่แบบ: เปิดช่องทางชำระ 2 จาก 4');

-- ข้อมูลกลาง
select is(tests.owner_a('select count(*) from ref_units'), '20', 'อ่านหน่วยกลางได้ 20 หน่วย');
select is(tests.owner_a('select count(*) from ref_banks'), '15', 'อ่านธนาคารได้ 15 รายการ');
select is(tests.owner_a($$with u as (update ref_banks set sort_order = 0 returning 1) select count(*) from u$$), 'ERR:42501', 'แก้ข้อมูลกลางไม่ได้');
select is(tests.public_anon('select count(*) from ref_units'), 'ERR:42501', 'anon key อ่านข้อมูลกลางไม่ได้');

-- ข้อมูลทดสอบของแต่ละร้าน (สร้างด้วย postgres เพราะการเขียนธุรกรรมเป็นงาน RPC ของ F1)
insert into packages (shop_id, name, adult_price, child_price) values
  (tests.shop_a(), 'แพ็กเกจ A', 29900, 14900),
  (tests.shop_b(), 'แพ็กเกจ B', 39900, 19900);
insert into suppliers (shop_id, name) values (tests.shop_b(), 'ซัพพลายเออร์ B');
insert into staff (shop_id, name, role) values
  (tests.shop_a(), 'พนักงาน A', 'cashier'),
  (tests.shop_b(), 'พนักงาน B', 'cashier');

insert into ctx select 'pair_a', tests.owner_a(format($$select pairing_code from create_device_pairing(%L, 'เครื่อง A')$$, tests.shop_a()));
insert into ctx select 'pair_b', tests.owner_b(format($$select pairing_code from create_device_pairing(%L, 'เครื่อง B')$$, tests.shop_b()));
create function tests.val(p_key text) returns text language sql as $$ select val from ctx where key = p_key $$;

-- จับคู่เครื่อง
select is(tests.owner_b(format($$select pairing_code from create_device_pairing(%L, 'x')$$, tests.shop_a())), 'ERR:42501', 'ออกรหัสจับคู่ให้ร้านอื่นไม่ได้');
select ok(
  (select max(p.expires_at) - now() > interval '23 hours'
   from private.device_pairings p join public.devices d on d.id = p.device_id
   where d.shop_id = tests.shop_a()),
  'รหัสจับคู่ใช้ได้ 24 ชั่วโมง เพื่อส่งเป็นลิงก์ทาง LINE');
select is(tests.owner_a(format($$select device_id from claim_device(%L)$$, tests.val('pair_a'))), 'ERR:42501', 'บัญชีเจ้าของใช้ claim_device ไม่ได้');
select is(tests.device_a($$select device_id from claim_device('WRONGCODE')$$), 'ERR:P0002', 'รหัสจับคู่ผิดใช้ไม่ได้');
select is(tests.device_a('select count(*) from shops'), '0', 'บัญชีเครื่องที่ยังไม่จับคู่ไม่เห็นร้าน');
select is(tests.device_a(format($$select shop_id from claim_device(%L)$$, tests.val('pair_a'))), tests.shop_a()::text, 'เครื่อง A จับคู่กับร้าน A สำเร็จ');
select is(tests.device_b(format($$select shop_id from claim_device(%L)$$, tests.val('pair_a'))), 'ERR:P0002', 'รหัสจับคู่ใช้ซ้ำไม่ได้');
select is(tests.device_b(format($$select shop_id from claim_device(%L)$$, tests.val('pair_b'))), tests.shop_b()::text, 'เครื่อง B จับคู่กับร้าน B สำเร็จ');

insert into bills (id, shop_id, device_id, no, business_date, at, subtotal, total, method_type, received)
select gen_random_uuid(), d.shop_id, d.id, '00000-' || d.code || '-000001', current_date, now(), 29900, 29900, 'cash', 29900
from devices d
where d.shop_id in (tests.shop_a(), tests.shop_b());

-- แยกข้อมูลรายร้าน
select is(tests.owner_a('select count(*) from shops'), '1', 'เจ้าของ A เห็นร้านเดียว');
select is(tests.owner_a(format('select count(*) from shops where id = %L', tests.shop_b())), '0', 'เจ้าของ A ไม่เห็นร้าน B');
select is(tests.owner_a(format('select count(*) from bills where shop_id = %L', tests.shop_b())), '0', 'เจ้าของ A ไม่เห็นบิลร้าน B');
select is(tests.owner_a('select count(*) from bills'), '1', 'เจ้าของ A เห็นบิลของตัวเอง');
select is(tests.owner_a(format('select count(*) from staff where shop_id = %L', tests.shop_b())), '0', 'เจ้าของ A ไม่เห็นพนักงานร้าน B');
select is(tests.outsider('select count(*) from shops'), '0', 'ผู้ใช้ที่ไม่มีสังกัดไม่เห็นร้าน');
select is(tests.outsider('select count(*) from bills'), '0', 'ผู้ใช้ที่ไม่มีสังกัดไม่เห็นบิล');
select is(tests.public_anon('select count(*) from bills'), 'ERR:42501', 'anon key อ่านบิลไม่ได้');
select is(tests.owner_a(format($$insert into packages (shop_id, name, adult_price, child_price) values (%L, 'x', 1, 1) returning 1$$, tests.shop_b())), 'ERR:42501', 'เจ้าของ A เพิ่มเมนูให้ร้าน B ไม่ได้');
select is(tests.owner_a(format($$with u as (update shops set name = 'hacked' where id = %L returning 1) select count(*) from u$$, tests.shop_b())), '0', 'เจ้าของ A แก้ร้าน B ไม่ได้');
select is(tests.owner_a('select count(*) from suppliers'), '0', 'เจ้าของ A ไม่เห็น supplier ร้าน B');
select throws_ok(format($$insert into ingredients (shop_id, name, unit, supplier_id) values (%L, 'x', 'กก.', %L)$$, tests.shop_a(), (select id from suppliers where shop_id = tests.shop_b())), '23503', null, 'FK กันการอ้าง supplier ข้ามร้าน');

-- สิทธิ์ของเครื่อง
select is(tests.device_a('select count(*) from packages'), '1', 'เครื่อง A อ่านเมนูร้านตัวเองได้');
select is(tests.device_a(format('select count(*) from packages where shop_id = %L', tests.shop_b())), '0', 'เครื่อง A ไม่เห็นเมนูร้าน B');
select is(tests.device_a(format($$insert into packages (shop_id, name, adult_price, child_price) values (%L, 'x', 1, 1) returning 1$$, tests.shop_a())), 'ERR:42501', 'เครื่องแก้เมนูไม่ได้');
select is(tests.device_a(format($$select pairing_code from create_device_pairing(%L, 'x')$$, tests.shop_a())), 'ERR:42501', 'เครื่องออกรหัสจับคู่เองไม่ได้');

-- ธุรกรรมเขียนตรงไม่ได้
select is(tests.owner_a(format($$insert into expenses (id, shop_id, business_date, at, type_name, amount) values (gen_random_uuid(), %L, current_date, now(), 'x', 1) returning 1$$, tests.shop_a())), 'ERR:42501', 'เจ้าของเขียนธุรกรรมตรงไม่ได้');
select is(tests.owner_a('truncate bills cascade'), 'ERR:42501', 'TRUNCATE ไม่ได้');

-- บิลแก้/ลบไม่ได้ แม้เป็น postgres
select throws_ok($$update bills set total = 1 where shop_id = tests.shop_a()$$, 'P0001', null, 'แก้ยอดบิลไม่ได้');
select throws_ok($$delete from bills where shop_id = tests.shop_a()$$, 'P0001', null, 'ลบบิลไม่ได้');
select throws_ok($$update bills set voided = true, void_reason = 'x', void_by = 'y', void_at = now(), total = 1 where shop_id = tests.shop_a()$$, 'P0001', null, 'แก้ยอดพร้อมยกเลิกไม่ได้');
select lives_ok($$update bills set voided = true, void_reason = 'ลูกค้าเปลี่ยนใจ', void_by = 'พนักงาน A', void_at = now() where shop_id = tests.shop_a()$$, 'ยกเลิกบิลได้');
select is((select count(*)::int from audit_log where shop_id = tests.shop_a() and action = 'void'), 1, 'การยกเลิกลง audit_log');
select throws_ok($$update bills set voided = false, void_reason = null, void_by = null, void_at = null where shop_id = tests.shop_a()$$, 'P0001', null, 'คืนสถานะบิลที่ยกเลิกแล้วไม่ได้');

-- PIN พนักงาน
insert into ctx select 'staff_a', id::text from staff where shop_id = tests.shop_a();
select hasnt_column('public', 'staff', 'pin_hash', 'ตาราง staff ไม่มี hash ของ PIN');
select is(tests.owner_a('select count(*) from private.staff_pins'), 'ERR:42501', 'อ่านตาราง PIN ตรง ๆ ไม่ได้');
select is(tests.owner_b(format($$select 1 from set_staff_pin(%L, '1234')$$, tests.val('staff_a'))), 'ERR:42501', 'ตั้ง PIN ให้พนักงานร้านอื่นไม่ได้');
select is(tests.device_a(format($$select 1 from set_staff_pin(%L, '1234')$$, tests.val('staff_a'))), 'ERR:42501', 'เครื่องตั้ง PIN เองไม่ได้');
select is(tests.owner_a(format($$select 1 from set_staff_pin(%L, '12')$$, tests.val('staff_a'))), 'ERR:22023', 'PIN ต้องเป็นตัวเลข 4 หลัก');
select is(tests.owner_a(format($$select 1 from set_staff_pin(%L, '1234')$$, tests.val('staff_a'))), '1', 'เจ้าของตั้ง PIN ได้');
select is(tests.device_a(format($$select verify_staff_pin(%L, '1234') ->> 'ok'$$, tests.val('staff_a'))), 'true', 'PIN ถูกต้องผ่าน');
select is(tests.device_b(format($$select verify_staff_pin(%L, '1234') ->> 'ok'$$, tests.val('staff_a'))), 'ERR:42501', 'เครื่องร้าน B ตรวจ PIN พนักงานร้าน A ไม่ได้');
select is(tests.outsider(format($$select verify_staff_pin(%L, '1234') ->> 'ok'$$, tests.val('staff_a'))), 'ERR:42501', 'ผู้ใช้นอกร้านตรวจ PIN ไม่ได้');
select is(tests.device_a(format($$select verify_staff_pin(%L, '0000') ->> 'attempts_left'$$, tests.val('staff_a'))), '4', 'ผิดครั้งที่ 1 เหลือ 4');
select tests.device_a(format($$select verify_staff_pin(%L, '0000')$$, tests.val('staff_a')));
select tests.device_a(format($$select verify_staff_pin(%L, '0000')$$, tests.val('staff_a')));
select is(tests.device_a(format($$select verify_staff_pin(%L, '0000') ->> 'attempts_left'$$, tests.val('staff_a'))), '1', 'ผิดครั้งที่ 4 เหลือ 1');
select is(tests.device_a(format($$select verify_staff_pin(%L, '0000') ->> 'reason'$$, tests.val('staff_a'))), 'locked', 'ผิดครบ 5 ครั้งถูกล็อก');
select is(tests.device_a(format($$select verify_staff_pin(%L, '1234') ->> 'reason'$$, tests.val('staff_a'))), 'locked', 'ระหว่างล็อก PIN ถูกก็เข้าไม่ได้');
update private.staff_pins set locked_until = now() - interval '1 second' where staff_id = tests.val('staff_a')::uuid;
select is(tests.device_a(format($$select verify_staff_pin(%L, '1234') ->> 'ok'$$, tests.val('staff_a'))), 'true', 'พ้นเวลาล็อกแล้วเข้าได้');

-- เพิกถอนเครื่อง
update devices set revoked_at = now() where shop_id = tests.shop_b();
select is(tests.device_b('select count(*) from packages'), '0', 'เครื่องที่ถูกเพิกถอนไม่เห็นข้อมูล');

-- เครื่องออกจากร้านเอง
select is(tests.owner_a('select leave_device()::text'), 'ERR:42501', 'บัญชีเจ้าของใช้ leave_device ไม่ได้');
select lives_ok($$select tests.device_a('select leave_device()::text')$$, 'เครื่อง A ออกจากร้านได้');
select is(tests.device_a('select count(*) from packages'), '0', 'ออกจากร้านแล้วเครื่องไม่เห็นข้อมูลร้าน');
select is(tests.device_a(format($$select shop_id from claim_device(%L)$$, tests.owner_a(format($$select pairing_code from create_device_pairing(%L, 'เครื่อง A2')$$, tests.shop_a())))), tests.shop_a()::text, 'ออกจากร้านแล้วบัญชีเครื่องเดิมจับคู่ใหม่ได้');
select is(tests.device_b(format($$select shop_id from claim_device(%L)$$, tests.owner_b(format($$select pairing_code from create_device_pairing(%L, 'เครื่อง B2')$$, tests.shop_b())))), tests.shop_b()::text, 'ถูกเพิกถอนแล้วบัญชีเครื่องเดิมจับคู่ใหม่ได้');

-- สิทธิ์เรียกฟังก์ชัน: ฟังก์ชันใหม่ได้ EXECUTE ให้ PUBLIC โดยอัตโนมัติ จึงต้องตรวจทุกตัว
select is(
  (select coalesce(string_agg(p.proname, ',' order by p.proname), '')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'private' and has_function_privilege('authenticated', p.oid, 'execute')),
  'can_manage_shop,can_read_org,can_read_shop,is_active_device_of,is_org_owner',
  'authenticated เรียกได้เฉพาะตัวช่วย RLS ใน private'
);
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')),
  0,
  'anon เรียกฟังก์ชันใน public ไม่ได้'
);

select * from finish();
rollback;
