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
select x.* from (
  select tests.owner_a($$select 1 from set_staff_pin('10000000-0000-0000-0000-000000000001', '1111')$$),
         tests.owner_b($$select 1 from set_staff_pin('10000000-0000-0000-0000-000000000003', '3333')$$)
) x;
select tests.set_val('token', tests.device_a($$select verify_staff_pin('10000000-0000-0000-0000-000000000001', '1111') ->> 'session_token'$$));
select tests.set_val('token_b', tests.device_b($$select verify_staff_pin('10000000-0000-0000-0000-000000000003', '3333') ->> 'session_token'$$));

-- ร้าน A ตัดวันตอนตี 4: วันทำการคิดแบบ settle_bill
update shops set day_cutoff_minutes = 240 where id = tests.val('shop')::uuid;
select tests.set_val('today',
  (((now() at time zone 'Asia/Bangkok') - interval '240 minutes')::date)::text);

insert into suppliers (id, shop_id, name) values
  ('20000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'ซัพพลายเออร์ A');
insert into ingredients (id, shop_id, name, unit) values
  ('30000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'หมู', 'กก.');
insert into expense_types (id, shop_id, name) values
  ('40000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, 'แก๊สทดสอบ');

insert into expenses (id, shop_id, business_date, at, type_id, type_name, amount, note) values
  ('50000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, tests.val('today')::date, now(),
   '40000000-0000-0000-0000-000000000001', 'แก๊สทดสอบ', 45000, 'ถังใหม่'),
  ('50000000-0000-0000-0000-000000000002', tests.val('shop')::uuid, tests.val('today')::date - 1, now() - interval '1 day',
   '40000000-0000-0000-0000-000000000001', 'แก๊สทดสอบ', 30000, 'เมื่อวาน');
insert into purchases (id, shop_id, business_date, at, supplier_id, note) values
  ('60000000-0000-0000-0000-000000000001', tests.val('shop')::uuid, tests.val('today')::date, now(),
   '20000000-0000-0000-0000-000000000001', '');
insert into purchase_lines (shop_id, purchase_id, ingredient_id, qty, total) values
  (tests.val('shop')::uuid, '60000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 2.5, 50000);

select tests.set_val('entries', tests.device_a(format($$select get_day_entries(%L)::text$$, tests.val('token'))));

select is(tests.val('entries')::jsonb ->> 'business_date', tests.val('today'), 'business date follows the shop cutoff');
select is(jsonb_array_length(tests.val('entries')::jsonb -> 'expenses'), 1, 'only today''s expenses are returned');
select is(tests.val('entries')::jsonb -> 'expenses' -> 0 ->> 'note', 'ถังใหม่', 'expense keeps its note');
select ok(not (tests.val('entries')::jsonb -> 'expenses' -> 0 ? 'amount'), 'cashier does not get the expense amount');
select is((tests.val('entries')::jsonb -> 'purchases' -> 0 -> 'lines' -> 0 ->> 'qty')::numeric, 2.5, 'purchase line keeps its quantity');
select ok(not (tests.val('entries')::jsonb -> 'purchases' -> 0 -> 'lines' -> 0 ? 'total'), 'cashier does not get the purchase total');

select is(
  tests.device_b(format($$select jsonb_array_length(get_day_entries(%L) -> 'expenses')::text$$, tests.val('token_b'))),
  '0', 'another shop sees none of these entries'
);
select is(
  tests.device_b(format($$select get_day_entries(%L)::text$$, tests.val('token'))),
  'ERR:42501', 'a token from another device is rejected'
);

select * from finish();
rollback;
