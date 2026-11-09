-- รันด้วย: supabase test db
-- ตัวเลขชุดเดียวกับ app/test/unit/vat_rules_test.dart
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(10);

-- ปัดลงแล้ว VAT แยกนอกคิดจากยอดหลังปัด: total 63900, vat = round(63900*7/107) = 4180, base + vat = total
select is(private.calc_bill_amounts(59800, 0, 'excluded', 7, 'down')::text, '(0,4180,-86,63900)', 'excluded + ปัดลง: VAT จากยอดหลังปัด');
select is((private.calc_bill_amounts(59800, 0, 'excluded', 7, 'down')).total - (private.calc_bill_amounts(59800, 0, 'excluded', 7, 'down')).vat, 59720::bigint, 'excluded + ปัดลง: ยอดก่อน VAT + VAT = total');
select is(private.calc_bill_amounts(59800, 0, 'excluded', 7, 'none')::text, '(0,4186,0,63986)', 'excluded ไม่ปัด: เหมือนเดิม');
select is(private.calc_bill_amounts(60000, 0, 'excluded', 7, 'down')::text, '(0,4200,0,64200)', 'excluded ปัดแต่ยอดลงตัว: VAT เดิม');
select is(private.calc_bill_amounts(59800, 0, 'included', 7, 'down')::text, '(0,3912,0,59800)', 'included: เหมือนเดิม');
select is(private.calc_bill_amounts(59850, 0, 'included', 7, 'down')::text, '(0,3912,-50,59800)', 'included + ปัดลง: VAT จากยอดหลังปัด');
select is(private.calc_bill_amounts(59800, 0, 'none', 7, 'down')::text, '(0,0,0,59800)', 'none: เหมือนเดิม');

-- trigger: กิจการไม่จด VAT ตั้ง VAT ไม่ได้
insert into auth.users (id, email, is_anonymous) values ('00000000-0000-0000-0000-0000000000a1', 'v@example.test', false);
create function pg_temp.try_vat(p_registered boolean, p_mode text) returns text language plpgsql as $$
declare v_org uuid;
begin
  insert into public.organizations (name, vat_registered) values ('vat-test', p_registered) returning id into v_org;
  insert into public.shops (org_id, name, vat_mode) values (v_org, 's', p_mode);
  return 'ok';
exception when others then return 'ERR:' || sqlstate;
end $$;
select is(pg_temp.try_vat(false, 'excluded'), 'ERR:23514', 'ไม่จด VAT: เพิ่มร้าน VAT แยกนอกไม่ได้');

create function pg_temp.try_turn_off() returns text language plpgsql as $$
declare v_org uuid;
begin
  insert into public.organizations (name, vat_registered) values ('vat-test2', true) returning id into v_org;
  insert into public.shops (org_id, name, vat_mode) values (v_org, 's', 'included');
  update public.organizations set vat_registered = false where id = v_org;
  return 'ok';
exception when others then return 'ERR:' || sqlstate;
end $$;
select is(pg_temp.try_turn_off(), 'ERR:23514', 'ปิดการจด VAT ขณะมีร้านใช้ VAT ไม่ได้');
select is(pg_temp.try_vat(true, 'excluded'), 'ok', 'จด VAT: ตั้ง VAT แยกนอกได้');

select * from finish();
rollback;
