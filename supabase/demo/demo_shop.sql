-- Demo shop สำหรับภาพโปรโมต (ข้อมูลสมมติทั้งหมด)
-- รันมือกับ Supabase Docker ในเครื่องเท่านั้น ห้ามใส่ใน config.toml [db.seed] และห้ามรันกับฐานข้อมูลจริง:
--   psql "$(supabase status -o env | sed -n 's/^DB_URL=\"\(.*\)\"$/\1/p')" -f supabase/demo/demo_shop.sql
-- รันซ้ำได้: ลบ org/shop/user ตาม UUID ตายตัวก่อน แล้วสร้างใหม่ ข้อมูลสุ่มใช้ hash (md5) จึงได้ผลเดิมทุกครั้ง
-- เงินเป็นสตางค์ (100 = 1 บาท) ใน DB นี้ shops.vat_rate เก็บเป็นเปอร์เซ็นต์ (7.00) ไม่ใช่ basis points
-- ล็อกอินเจ้าของ: demo@keptoh.local / KepTohDemo123!   PIN พนักงานทุกคน: 1234
-- รหัสจับคู่เครื่อง iPad แคชเชียร์ (ใช้ได้ 1 ครั้ง ต่ออายุทุกครั้งที่รันไฟล์นี้): DEC0DE0001
\set ON_ERROR_STOP on
begin;

create function pg_temp.rnd(k text) returns double precision language sql immutable as
$$ select (('x' || substr(md5(k), 1, 7))::bit(28)::int)::double precision / 268435456.0 $$;
create function pg_temp.uid(k text) returns uuid language sql immutable as
$$ select md5('keptoh-demo:' || k)::uuid $$;
create function pg_temp.org_id() returns uuid language sql immutable as $$ select 'de000000-0000-4000-8000-000000000001'::uuid $$;
create function pg_temp.shop_id() returns uuid language sql immutable as $$ select 'de000000-0000-4000-8000-000000000002'::uuid $$;
create function pg_temp.owner_id() returns uuid language sql immutable as $$ select 'de000000-0000-4000-8000-000000000003'::uuid $$;
create function pg_temp.dev_id() returns uuid language sql immutable as $$ select 'de000000-0000-4000-8000-000000000004'::uuid $$;
create function pg_temp.today() returns date language sql stable as $$ select (now() at time zone 'Asia/Bangkok')::date $$;
-- เวลา (นาทีของวัน) ตามเวลาไทย
create function pg_temp.bkk(d date, mins int) returns timestamptz language sql immutable as
$$ select (d::timestamp + mins * interval '1 minute') at time zone 'Asia/Bangkok' $$;

-- ============ 1) ลบข้อมูลเดโมเดิม ============
-- ตารางบิล/รอบสั่ง/audit กันแก้ลบด้วย trigger จึงปิดชั่วคราวเฉพาะตอนล้าง แล้วเปิดกลับก่อนสร้างข้อมูลใหม่
alter table public.bills disable trigger user;
alter table public.bill_lines disable trigger user;
alter table public.table_rounds disable trigger user;
alter table public.table_adjustments disable trigger user;
alter table public.audit_log disable trigger user;
alter table public.settled_table_events disable trigger user;

delete from public.audit_log where shop_id = pg_temp.shop_id();
delete from public.settled_table_events where shop_id = pg_temp.shop_id();
delete from public.bill_lines where shop_id = pg_temp.shop_id();
update public.bills set replaces_bill_id = null where shop_id = pg_temp.shop_id();
delete from public.bills where shop_id = pg_temp.shop_id();
delete from public.table_session_aliases where shop_id = pg_temp.shop_id();
delete from public.table_adjustments where shop_id = pg_temp.shop_id();
delete from public.table_rounds where shop_id = pg_temp.shop_id();
delete from public.table_sessions where shop_id = pg_temp.shop_id();
delete from public.shifts where shop_id = pg_temp.shop_id();
delete from public.purchase_lines where shop_id = pg_temp.shop_id();
delete from public.purchases where shop_id = pg_temp.shop_id();
delete from public.expenses where shop_id = pg_temp.shop_id();
delete from public.stock_counts where shop_id = pg_temp.shop_id();
delete from public.initial_stock where shop_id = pg_temp.shop_id();
delete from public.ingredient_unit_conversions where shop_id = pg_temp.shop_id();
delete from public.ingredients where shop_id = pg_temp.shop_id();
delete from public.suppliers where shop_id = pg_temp.shop_id();
delete from public.addons where shop_id = pg_temp.shop_id();
delete from public.packages where shop_id = pg_temp.shop_id();
delete from public.dining_tables where shop_id = pg_temp.shop_id();
delete from public.categories where shop_id = pg_temp.shop_id();
delete from public.expense_types where shop_id = pg_temp.shop_id();
delete from public.fixed_costs where shop_id = pg_temp.shop_id();
delete from public.void_reasons where shop_id = pg_temp.shop_id();
delete from public.payment_methods where shop_id = pg_temp.shop_id();
delete from public.bank_accounts where shop_id = pg_temp.shop_id();
delete from private.staff_sessions where staff_id in (select id from public.staff where shop_id = pg_temp.shop_id());
delete from private.staff_offline_tokens where staff_id in (select id from public.staff where shop_id = pg_temp.shop_id());
delete from private.staff_pins where staff_id in (select id from public.staff where shop_id = pg_temp.shop_id());
delete from private.device_pairings where device_id in (select id from public.devices where shop_id = pg_temp.shop_id());
delete from public.staff where shop_id = pg_temp.shop_id();
delete from public.devices where shop_id = pg_temp.shop_id();
delete from public.memberships where org_id = pg_temp.org_id();
delete from public.shops where id = pg_temp.shop_id();
delete from public.organizations where id = pg_temp.org_id();
delete from auth.users where id = pg_temp.owner_id() or email = 'demo@keptoh.local';

alter table public.bills enable trigger user;
alter table public.bill_lines enable trigger user;
alter table public.table_rounds enable trigger user;
alter table public.table_adjustments enable trigger user;
alter table public.audit_log enable trigger user;
alter table public.settled_table_events enable trigger user;

-- ============ 2) เจ้าของ กิจการ สาขา ============
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
) values (
  '00000000-0000-0000-0000-000000000000', pg_temp.owner_id(), 'authenticated', 'authenticated',
  'demo@keptoh.local', extensions.crypt('KepTohDemo123!', extensions.gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''
);
insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
values (
  pg_temp.owner_id()::text, pg_temp.owner_id(),
  jsonb_build_object('sub', pg_temp.owner_id()::text, 'email', 'demo@keptoh.local', 'email_verified', true, 'phone_verified', false),
  'email', now(), now(), now()
);

-- เลขผู้เสียภาษีสมมติ (ผ่าน checksum หลักที่ 13)
insert into public.organizations (id, name, tax_id, vat_registered)
values (pg_temp.org_id(), 'บริษัท เก็บโต๊ะ ตัวอย่าง จำกัด', '0105559990018', true);

insert into public.shops (
  id, org_id, name, branch_code, branch_name, address, phone, promptpay,
  vat_mode, vat_rate, service_pct, default_float, receipt_footer, use_timer, pay_timing,
  theme_mode, theme_palette, created_at
) values (
  pg_temp.shop_id(), pg_temp.org_id(), 'หมูกระทะ เก็บโต๊ะ สาขาตัวอย่าง', '00000', 'สาขาตัวอย่าง',
  '99/9 ถนนตัวอย่าง แขวงตัวอย่าง เขตตัวอย่าง กรุงเทพมหานคร 10110', '02-000-0000', '0800000000',
  'included', 7, 0, 100000, 'ขอบคุณที่ใช้บริการ', true, 'after',
  'light', 'orange', pg_temp.bkk(pg_temp.today() - 31, 360) -- แอปใช้ shops.created_at เป็นวันเริ่มคำนวณบัญชี/กำไร ต้องย้อนไปก่อนวันที่มีข้อมูล
);

insert into public.memberships (user_id, org_id, role) values (pg_temp.owner_id(), pg_temp.org_id(), 'owner');

-- เหมือน create_organization_with_shop: คัดลอกแม่แบบเข้าร้าน
insert into public.categories (shop_id, kind, name, sort_order)
select pg_temp.shop_id(), replace(t.kind, '_category', ''), t.name, t.sort_order
from public.ref_shop_templates t where t.kind in ('ingredient_category', 'addon_category');
insert into public.expense_types (shop_id, name)
select pg_temp.shop_id(), t.name from public.ref_shop_templates t where t.kind = 'expense_type' order by t.sort_order;
insert into public.fixed_costs (shop_id, name, amount, active)
select pg_temp.shop_id(), t.name,
  case t.name when 'ค่าเช่า' then 4500000 when 'เงินเดือนพนักงาน' then 9000000 when 'ค่าน้ำ' then 250000
              when 'ค่าไฟ' then 1800000 when 'อินเทอร์เน็ต/แอป' then 59900 else 0 end,
  t.name <> 'ค่าผ่อนอุปกรณ์'
from public.ref_shop_templates t where t.kind = 'fixed_cost' order by t.sort_order;
insert into public.void_reasons (shop_id, name, sort_order)
select pg_temp.shop_id(), t.name, t.sort_order from public.ref_shop_templates t where t.kind = 'void_reason';
-- เดโมเปิดช่องทางโอนด้วย เพื่อให้มีทั้งเงินสด/QR/โอน
insert into public.payment_methods (shop_id, name, type, active)
select pg_temp.shop_id(), t.name, t.payment_type, t.active or t.payment_type = 'transfer'
from public.ref_shop_templates t where t.kind = 'payment_method' order by t.sort_order;

insert into public.bank_accounts (id, shop_id, bank_name, account_no, account_name)
values (pg_temp.uid('bank:kbank'), pg_temp.shop_id(), 'กสิกรไทย', '000-0-00000-0', 'บจก. เก็บโต๊ะ ตัวอย่าง');

-- ============ 3) โต๊ะ แพ็กเกจ เมนูเสริม ============
insert into public.dining_tables (id, shop_id, name, seats, zone)
select pg_temp.uid('tbl:' || n), pg_temp.shop_id(), n, s, z
from (
  select 'A' || g as n, 4 as s, 'ในร้าน' as z from generate_series(1, 10) g
  union all select 'B' || g, 6, 'ลาน' from generate_series(1, 7) g
  union all select 'V1', 8, 'VIP' union all select 'V2', 10, 'VIP' union all select 'V3', 10, 'VIP'
) x;

create temp table t_pkg_def on commit drop as
select * from (values
  (1, 'บุฟเฟ่ต์ 199', 19900, 9950, 90),
  (2, 'บุฟเฟ่ต์ 259', 25900, 12950, 90),
  (3, 'พรีเมียม 329', 32900, 16450, 120),
  (4, 'ซีฟู้ดพรีเมียม 399', 39900, 19950, 120)
) v(idx, name, adult, child, lim);
insert into public.packages (id, shop_id, name, adult_price, child_price, child_rule, free_rule, time_limit_min)
select pg_temp.uid('pkg:' || idx), pg_temp.shop_id(), name, adult, child,
  'สูง 100-140 ซม. ครึ่งราคา', 'ต่ำกว่า 100 ซม. ทานฟรี', lim
from t_pkg_def;

create temp table t_addon_def on commit drop as
select * from (values
  ('water', 'น้ำเปล่า', 'เครื่องดื่ม', 1000, 300, 120, 0.50),
  ('ice', 'น้ำแข็ง', 'เครื่องดื่ม', 2000, 700, 60, 0.60),
  ('coke', 'โค้ก', 'เครื่องดื่ม', 2000, 1100, 96, 0.35),
  ('sprite', 'สไปรท์', 'เครื่องดื่ม', 2000, 1100, 60, 0.20),
  ('chang', 'เบียร์ช้าง', 'เครื่องดื่ม', 6500, 4200, 144, 0.30),
  ('singha', 'เบียร์สิงห์', 'เครื่องดื่ม', 7000, 4500, 96, 0.15),
  ('leo', 'เบียร์ลีโอ', 'เครื่องดื่ม', 6500, 4200, 72, 0.15),
  ('cheese', 'ชีสเยิ้ม', 'อื่นๆ', 5900, 2800, 4, 0.25),
  ('pork', 'หมูสไลซ์เพิ่ม', 'อื่นๆ', 8900, 4500, 25, 0.30),
  ('beef', 'เนื้อวัวสไลซ์เพิ่ม', 'อื่นๆ', 12900, 7500, 0, 0.12),
  ('icecream', 'ไอศกรีมกะทิ', 'ของหวาน', 3500, 1400, 40, 0.20),
  ('rice', 'ข้าวสวย', 'อื่นๆ', 1000, 300, 80, 0.25)
) v(key, name, category, price, cost, stock, prob);
insert into public.addons (id, shop_id, name, category, price, cost, stock)
select pg_temp.uid('addon:' || key), pg_temp.shop_id(), name, category, price, cost, stock from t_addon_def;

-- ============ 4) พนักงาน เครื่อง ============
insert into public.staff (id, shop_id, name, role, can_view_costs) values
  (pg_temp.uid('staff:owner'), pg_temp.shop_id(), 'สมชาย ใจดี', 'owner', true),
  (pg_temp.uid('staff:nida'), pg_temp.shop_id(), 'นิดา รักงาน', 'manager', true),
  (pg_temp.uid('staff:mali'), pg_temp.shop_id(), 'มะลิ สุขใจ', 'cashier', false),
  (pg_temp.uid('staff:boss'), pg_temp.shop_id(), 'บอส เก่งกาจ', 'cashier', false);
insert into private.staff_pins (staff_id, pin_hash)
select s.id, extensions.crypt('1234', extensions.gen_salt('bf')) from public.staff s where s.shop_id = pg_temp.shop_id();

insert into public.devices (id, shop_id, code, name, created_by, rd_machine_code)
values (pg_temp.dev_id(), pg_temp.shop_id(), 'POS01', 'iPad แคชเชียร์', pg_temp.owner_id(), 'DEMOPOS01');
insert into private.device_pairings (device_id, code_hash, expires_at)
values (pg_temp.dev_id(), encode(extensions.digest('DEC0DE0001', 'sha256'), 'hex'), now() + interval '365 days');

-- ============ 5) ซัพพลายเออร์ วัตถุดิบ ============
insert into public.suppliers (id, shop_id, name, phone) values
  (pg_temp.uid('sup:1'), pg_temp.shop_id(), 'ร้านแสงทอง ค้าเนื้อสัตว์', '02-000-0101'),
  (pg_temp.uid('sup:2'), pg_temp.shop_id(), 'ตลาดผักสด ป้าศรี', '02-000-0102'),
  (pg_temp.uid('sup:3'), pg_temp.shop_id(), 'ซันไรส์ ซัพพลาย', '02-000-0103');

create temp table t_ing_def on commit drop as
select n, name, unit, cost, par, sup, category, round(uph * 1.75, 4) as uph, loc, freq from (values
  (1, 'สันคอหมูสไลซ์', 'กก.', 18500, 30, 1, 'เนื้อหมู', 0.12, 'fridge', 'daily'),
  (2, 'สามชั้นสไลซ์', 'กก.', 16500, 25, 1, 'เนื้อหมู', 0.10, 'fridge', 'daily'),
  (3, 'หมูหมักนุ่ม', 'กก.', 15500, 15, 1, 'เนื้อหมู', 0.06, 'fridge', 'daily'),
  (4, 'เบคอนสไลซ์', 'กก.', 21000, 6, 1, 'เนื้อหมู', 0.02, 'fridge', 'daily'),
  (5, 'เนื้อวัวสไลซ์', 'กก.', 32000, 8, 1, 'เนื้อวัว/ไก่', 0.03, 'freezer', 'daily'),
  (6, 'อกไก่หมัก', 'กก.', 9500, 10, 1, 'เนื้อวัว/ไก่', 0.04, 'fridge', 'daily'),
  (7, 'กุ้งขาว', 'กก.', 28000, 8, 1, 'อาหารทะเล', 0.03, 'freezer', 'daily'),
  (8, 'ปลาหมึก', 'กก.', 22000, 5, 1, 'อาหารทะเล', 0.02, 'freezer', 'daily'),
  (9, 'ผักกาดขาว', 'กก.', 2500, 12, 2, 'ผัก', 0.05, 'fridge', 'daily'),
  (10, 'ผักบุ้ง', 'มัด', 1000, 25, 2, 'ผัก', 0.10, 'fridge', 'daily'),
  (11, 'เห็ดเข็มทอง', 'ถุง', 2000, 15, 2, 'ผัก', 0.06, 'fridge', 'daily'),
  (12, 'ไข่ไก่', 'ฟอง', 400, 100, 2, 'อื่นๆ', 0.25, 'dry', 'daily'),
  (13, 'วุ้นเส้น', 'แพ็ค', 1800, 6, 3, 'อื่นๆ', 0.02, 'dry', 'weekly'),
  (14, 'น้ำจิ้มแจ่ว', 'ขวด', 6500, 3, 3, 'น้ำจิ้ม/เครื่องปรุง', 0.01, 'dry', 'daily'),
  (15, 'น้ำจิ้มซีฟู้ด', 'ขวด', 7000, 3, 3, 'น้ำจิ้ม/เครื่องปรุง', 0.008, 'dry', 'daily'),
  (16, 'น้ำมันพืช', 'ลิตร', 5500, 4, 3, 'น้ำจิ้ม/เครื่องปรุง', 0.01, 'dry', 'weekly'),
  (17, 'ถ่านไม้', 'ถุง', 12000, 8, 3, 'วัสดุสิ้นเปลือง', 0.03, 'dry', 'daily'),
  (18, 'ฟอยล์รองกระทะ', 'แพ็ค', 9000, 2, 3, 'วัสดุสิ้นเปลือง', 0.005, 'dry', 'weekly'),
  (19, 'ทิชชู่', 'แพ็ค', 4500, 3, 3, 'วัสดุสิ้นเปลือง', 0.01, 'dry', 'weekly'),
  (20, 'ข้าวสารหอมมะลิ', 'กก.', 3800, 12, 3, 'อื่นๆ', 0.05, 'dry', 'weekly')
) v(n, name, unit, cost, par, sup, category, uph, loc, freq);
insert into public.ingredients (id, shop_id, name, unit, last_cost, par, supplier_id, category, use_per_head, location, count_freq)
select pg_temp.uid('ing:' || n), pg_temp.shop_id(), name, unit, cost, par, pg_temp.uid('sup:' || sup), category, uph, loc, freq
from t_ing_def;
insert into public.ingredient_unit_conversions (shop_id, ingredient_id, unit, factor)
values (pg_temp.shop_id(), pg_temp.uid('ing:12'), 'แผง', 30);
insert into public.initial_stock (shop_id, ingredient_id, qty, cost)
select pg_temp.shop_id(), pg_temp.uid('ing:' || n), par * 2, cost from t_ing_def;

-- ============ 6) 30 วันที่ผ่านมา + วันนี้: บิล ============
create temp table t_days on commit drop as
select d, d = pg_temp.today() as is_today,
  case when d = pg_temp.today() then 25
       else least(80, 40 + floor(pg_temp.rnd('n:' || d) * 41)::int + case when extract(dow from d) in (5, 6, 0) then 10 else 0 end) end as n,
  pg_temp.uid('shift:' || d) as shift_id,
  case when (pg_temp.today() - d) % 2 = 0 then pg_temp.uid('staff:mali') else pg_temp.uid('staff:boss') end as staff_id
from (select pg_temp.today() - g as d from generate_series(0, 30) g) x;

create temp table t_b1 on commit drop as
select pg_temp.uid('bill:' || d.d || ':' || k) as bill_id, d.d, k, d.n, d.shift_id, d.staff_id, d.is_today,
  case when r.pk < .30 then 1 when r.pk < .65 then 2 when r.pk < .87 then 3 else 4 end as pkg_idx,
  1 + floor(power(r.ha, 1.4) * 8)::int as a,
  case when r.hc < .35 then 1 + floor(r.hc2 * 3)::int else 0 end as c0,
  case when r.hf < .10 then 1 else 0 end as f,
  r.rt, r.pt, r.po, r.pdw, r.pj, r.r2, r.rm, r.rk, r.rg
from t_days d
cross join lateral generate_series(1, d.n) k
cross join lateral (select
  pg_temp.rnd('pk:' || d.d || ':' || k) pk, pg_temp.rnd('ha:' || d.d || ':' || k) ha,
  pg_temp.rnd('hc:' || d.d || ':' || k) hc, pg_temp.rnd('hc2:' || d.d || ':' || k) hc2,
  pg_temp.rnd('hf:' || d.d || ':' || k) hf, pg_temp.rnd('rt:' || d.d || ':' || k) rt,
  pg_temp.rnd('pt:' || d.d || ':' || k) pt, pg_temp.rnd('po:' || d.d || ':' || k) po,
  pg_temp.rnd('pdw:' || d.d || ':' || k) pdw, pg_temp.rnd('pj:' || d.d || ':' || k) pj,
  pg_temp.rnd('r2:' || d.d || ':' || k) r2, pg_temp.rnd('rm:' || d.d || ':' || k) rm,
  pg_temp.rnd('rk:' || d.d || ':' || k) rk, pg_temp.rnd('rg:' || d.d || ':' || k) rg
) r;

create temp table t_b2 on commit drop as
select b.*, least(b.c0, 10 - b.a) as c,
  55 + floor(b.pdw * 50)::int as dwell,
  case when b.pt < .22 then 690 + floor(b.po * 150)::int else 1020 + floor(b.po * 270)::int end as open_min
from t_b1 b;

create temp table t_b3 on commit drop as
select b.bill_id, b.d, b.k, b.shift_id, b.staff_id, b.is_today, b.pkg_idx, b.a, b.c, b.f, b.r2, b.rm, b.rk, b.rg,
  case when b.a + b.c <= 4 then 'A' || (1 + floor(b.rt * 10))::int
       when b.a + b.c <= 6 then 'B' || (1 + floor(b.rt * 7))::int
       when b.a + b.c <= 8 then 'V' || (1 + floor(b.rt * 3))::int
       else 'V' || (2 + floor(b.rt * 2))::int end as table_name,
  case when b.is_today
    then greatest(pg_temp.bkk(b.d, 1), now() - interval '5 minutes' - ((b.n - b.k + b.pj) / b.n * 380) * interval '1 minute')
    else pg_temp.bkk(b.d, b.open_min + b.dwell) end as at_ts,
  b.dwell
from t_b2 b;

-- เมนูเสริมต่อบิล: round_no 1 = รอบแรก, 2 = สั่งเพิ่มภายหลัง
create temp table t_ba on commit drop as
select b.bill_id, a.id as addon_id, a.name, a.price, a.cost,
  1 + floor(pg_temp.rnd('aq:' || b.bill_id || a.key) * greatest(1, (b.a + b.c) / 1.5))::int as qty,
  case when b.r2 < .5 and pg_temp.rnd('ar:' || b.bill_id || a.key) < .35 then 2 else 1 end as round_no
from t_b3 b
cross join (select pg_temp.uid('addon:' || key) id, key, name, price, cost, prob from t_addon_def) a
where pg_temp.rnd('ap:' || b.bill_id || a.key) < a.prob;

create temp table t_pay on commit drop as
select m.type, m.id, m.name from public.payment_methods m where m.shop_id = pg_temp.shop_id();

create temp table t_priced on commit drop as
select b.bill_id, b.d, b.shift_id, b.staff_id, s.name as staff_name, b.is_today, b.a, b.c, b.f,
  b.table_name, pg_temp.uid('tbl:' || b.table_name) as table_id,
  p.id as pkg_id, p.name as pkg_name, p.adult_price as adult, p.child_price as child, p.time_limit_min as limit_min,
  b.at_ts - b.dwell * interval '1 minute' as open_ts, b.at_ts,
  pg_temp.uid('sess:' || b.bill_id) as session_id,
  sub.subtotal, ca.service, ca.vat, ca.rounding, ca.total,
  case when b.rm < .45 then 'cash' when b.rm < .85 then 'qr' else 'transfer' end as mtype,
  case when b.is_today then 'normal' when b.rk < .004 then 'void' when b.rk < .008 then 'reissue'
       when b.rk < .012 then 'full' else 'normal' end as kind,
  b.rg
from t_b3 b
join public.packages p on p.id = pg_temp.uid('pkg:' || b.pkg_idx)
join public.staff s on s.id = b.staff_id
cross join lateral (
  select b.a * p.adult_price + b.c * p.child_price
    + coalesce((select sum(x.qty * x.price) from t_ba x where x.bill_id = b.bill_id), 0) as subtotal
) sub
cross join lateral private.calc_bill_amounts(sub.subtotal, 0::numeric, 'included', 7::numeric, 'down') ca;

-- บิลทั้งหมด: ต้นฉบับ (o) + บิลออกแทนจาก reissue / ใบกำกับเต็มรูป (r)
create temp table t_all on commit drop as
select u.*, pm.id as method_id, pm.name as method_name,
  case when u.mt = 'cash' then (ceil(u.total::numeric / gr.g) * gr.g)::bigint else u.total end as received
from (
  select p.bill_id as id, p.bill_id as src_id, 'o' as part, p.at_ts as bill_at, p.mtype as mt,
    (p.kind <> 'normal') as voided,
    case p.kind when 'void' then (array['คีย์จำนวนคนผิด', 'เลือกแพ็กเกจผิด', 'ลูกค้าเปลี่ยนใจ'])[1 + floor(pg_temp.rnd('vr:' || p.bill_id) * 3)::int]
                when 'reissue' then 'ชำระเงินผิดช่องทาง' when 'full' then 'ออกใบกำกับภาษีเต็มรูปแทน' end as void_reason,
    case p.kind when 'normal' then null else 'นิดา รักงาน' end as void_by,
    case p.kind when 'normal' then null::timestamptz when 'void' then p.at_ts + interval '6 minutes'
                when 'reissue' then p.at_ts + interval '8 minutes' else p.at_ts + interval '20 minutes' end as void_at,
    false as is_full, null::uuid as replaces, p.*
  from t_priced p
  union all
  select pg_temp.uid('repl:' || p.bill_id), p.bill_id, 'r',
    p.at_ts + case p.kind when 'full' then interval '20 minutes' else interval '8 minutes' end,
    case when p.kind = 'full' then p.mtype when p.mtype = 'cash' then 'qr' else 'cash' end,
    false, null, null, null, (p.kind = 'full'), p.bill_id, p.*
  from t_priced p where p.kind in ('reissue', 'full')
) u
join t_pay pm on pm.type = u.mt
cross join lateral (select (array[10000, 50000, 100000])[1 + floor(u.rg * 3)::int] as g) gr;

insert into public.shifts (id, shop_id, device_id, staff_id, opened_at, float_amount, closed_at, counted, closed_by)
select d.shift_id, pg_temp.shop_id(), pg_temp.dev_id(), d.staff_id,
  case when d.is_today then greatest(pg_temp.bkk(d.d, 1), least(pg_temp.bkk(d.d, 630), now() - interval '7 hours'))
       else pg_temp.bkk(d.d, 630) end,
  100000,
  case when d.is_today then null else pg_temp.bkk(d.d, 1425) end,
  case when d.is_today then null
       else 100000 + coalesce(c.cash, 0) - case when pg_temp.rnd('var:' || d.d) < .8 then 0 else floor(pg_temp.rnd('var2:' || d.d) * 5)::int * 100 end end,
  case when d.is_today then null else d.staff_id::text end
from t_days d
left join (select a.d, sum(a.total) as cash from t_all a where a.mt = 'cash' and not a.voided group by a.d) c on c.d = d.d;

insert into public.table_sessions (id, shop_id, table_id, package_id, opened_at, closed_at, timing)
select p.session_id, pg_temp.shop_id(), p.table_id, p.pkg_id, p.open_ts, p.at_ts, 'after' from t_priced p;

insert into public.table_rounds (id, shop_id, session_id, at, staff_id, source, heads_a, heads_c, heads_f, addons)
select pg_temp.uid('rd1:' || p.bill_id), pg_temp.shop_id(), p.session_id, p.open_ts, p.staff_id, 'pos', p.a, p.c, p.f,
  coalesce((select jsonb_object_agg(x.addon_id::text, x.qty) from t_ba x where x.bill_id = p.bill_id and x.round_no = 1), '{}'::jsonb)
from t_priced p
union all
select pg_temp.uid('rd2:' || p.bill_id), pg_temp.shop_id(), p.session_id, p.open_ts + interval '35 minutes', p.staff_id, 'pos', 0, 0, 0,
  (select jsonb_object_agg(x.addon_id::text, x.qty) from t_ba x where x.bill_id = p.bill_id and x.round_no = 2)
from t_priced p where exists (select 1 from t_ba x where x.bill_id = p.bill_id and x.round_no = 2);

-- ต้นฉบับก่อน แล้วบิลที่ออกแทน (FK replaces_bill_id)
insert into public.bills (
  id, shop_id, device_id, shift_id, session_id, no, business_date, at, table_id, table_name, staff_id, staff_name, package_id,
  subtotal, service, vat, rounding, total, heads_a, heads_c, heads_f,
  method_id, method_name, method_type, received, change_amount, vat_mode, vat_rate,
  bank_account_id, bank_account_info, eat_until, time_limit_min,
  voided, void_reason, void_by, void_at, created_at,
  rd_machine_code, is_tax_invoice, replaces_bill_id, is_full_invoice, buyer_name, buyer_tax_id, buyer_branch, buyer_address
)
select x.id, pg_temp.shop_id(), pg_temp.dev_id(), x.shift_id, x.session_id,
  case when x.is_full then '00000-F-' || lpad(x.sn::text, 6, '0') else '00000-POS01-' || lpad(x.sn::text, 6, '0') end,
  (x.bill_at at time zone 'Asia/Bangkok')::date, x.bill_at, x.table_id, x.table_name, x.staff_id, x.staff_name, x.pkg_id,
  x.subtotal, x.service, x.vat, x.rounding, x.total, x.a, x.c, x.f,
  x.method_id, x.method_name, x.mt, x.received, x.received - x.total, 'included', 7,
  case when x.mt = 'transfer' then pg_temp.uid('bank:kbank') end,
  case when x.mt = 'transfer' then 'กสิกรไทย · 000-0-00000-0' end,
  x.open_ts + x.limit_min * interval '1 minute', x.limit_min,
  x.voided, x.void_reason, x.void_by, x.void_at, x.bill_at,
  'DEMOPOS01', true, x.replaces, x.is_full,
  case when x.is_full then (array['บริษัท ตัวอย่าง เทรดดิ้ง จำกัด', 'ห้างหุ้นส่วนจำกัด ตัวอย่างการค้า', 'บริษัท ตัวอย่าง โลจิสติกส์ จำกัด'])[1 + floor(pg_temp.rnd('by:' || x.id) * 3)::int] end,
  case when x.is_full then (array['0105559990026', '0105559990034', '0105559990042'])[1 + floor(pg_temp.rnd('by:' || x.id) * 3)::int] end,
  case when x.is_full then '00000' end,
  case when x.is_full then '88/8 ถนนตัวอย่าง แขวงตัวอย่าง เขตตัวอย่าง กรุงเทพมหานคร 10500' end
from (select a.*, row_number() over (partition by a.is_full order by a.bill_at, a.id) as sn from t_all a) x
where x.part = 'o';

insert into public.bills (
  id, shop_id, device_id, shift_id, session_id, no, business_date, at, table_id, table_name, staff_id, staff_name, package_id,
  subtotal, service, vat, rounding, total, heads_a, heads_c, heads_f,
  method_id, method_name, method_type, received, change_amount, vat_mode, vat_rate,
  bank_account_id, bank_account_info, eat_until, time_limit_min,
  voided, void_reason, void_by, void_at, created_at,
  rd_machine_code, is_tax_invoice, replaces_bill_id, is_full_invoice, buyer_name, buyer_tax_id, buyer_branch, buyer_address
)
select x.id, pg_temp.shop_id(), pg_temp.dev_id(), x.shift_id, x.session_id,
  case when x.is_full then '00000-F-' || lpad(x.sn::text, 6, '0') else '00000-POS01-' || lpad(x.sn::text, 6, '0') end,
  (x.bill_at at time zone 'Asia/Bangkok')::date, x.bill_at, x.table_id, x.table_name, x.staff_id, x.staff_name, x.pkg_id,
  x.subtotal, x.service, x.vat, x.rounding, x.total, x.a, x.c, x.f,
  x.method_id, x.method_name, x.mt, x.received, x.received - x.total, 'included', 7,
  case when x.mt = 'transfer' then pg_temp.uid('bank:kbank') end,
  case when x.mt = 'transfer' then 'กสิกรไทย · 000-0-00000-0' end,
  x.open_ts + x.limit_min * interval '1 minute', x.limit_min,
  x.voided, x.void_reason, x.void_by, x.void_at, x.bill_at,
  'DEMOPOS01', true, x.replaces, x.is_full,
  case when x.is_full then (array['บริษัท ตัวอย่าง เทรดดิ้ง จำกัด', 'ห้างหุ้นส่วนจำกัด ตัวอย่างการค้า', 'บริษัท ตัวอย่าง โลจิสติกส์ จำกัด'])[1 + floor(pg_temp.rnd('by:' || x.src_id) * 3)::int] end,
  case when x.is_full then (array['0105559990026', '0105559990034', '0105559990042'])[1 + floor(pg_temp.rnd('by:' || x.src_id) * 3)::int] end,
  case when x.is_full then '00000' end,
  case when x.is_full then '88/8 ถนนตัวอย่าง แขวงตัวอย่าง เขตตัวอย่าง กรุงเทพมหานคร 10500' end
from (select a.*, row_number() over (partition by a.is_full order by a.bill_at, a.id) as sn from t_all a) x
where x.part = 'r';

create temp table t_lines on commit drop as
select p.bill_id, 1 as sort_key, 'buffet' as type, null::text as item_id, p.pkg_name || ' · ผู้ใหญ่' as name, p.a as qty, p.adult as price, null::bigint as cost
from t_priced p where p.a > 0
union all
select p.bill_id, 2, 'buffet', null, p.pkg_name || ' · เด็ก', p.c, p.child, null from t_priced p where p.c > 0
union all
select p.bill_id, 3, 'buffet', null, 'เด็กเล็ก (ทานฟรี)', p.f, 0, null from t_priced p where p.f > 0
union all
select x.bill_id, 4, 'addon', x.addon_id::text, x.name, sum(x.qty)::int, x.price, x.cost
from t_ba x group by x.bill_id, x.addon_id, x.name, x.price, x.cost;

insert into public.bill_lines (shop_id, bill_id, line_no, type, item_id, name, qty, price, cost)
select pg_temp.shop_id(), a.id, row_number() over (partition by a.id order by l.sort_key, l.name), l.type, l.item_id, l.name, l.qty, l.price, l.cost
from t_all a join t_lines l on l.bill_id = a.src_id;

insert into public.settled_table_events (event_id, shop_id, bill_id)
select r.id, pg_temp.shop_id(), p.bill_id
from t_priced p join public.table_rounds r on r.shop_id = pg_temp.shop_id() and r.session_id = p.session_id;

update public.devices set receipt_seq = (select count(*) from t_all where not is_full) where id = pg_temp.dev_id();
update public.shops set full_invoice_seq = (select count(*) from t_all where is_full) where id = pg_temp.shop_id();

-- ============ 7) ค่าใช้จ่ายรายวัน ============
create temp table t_exp_def on commit drop as
select * from (values
  ('แก๊ส', 0.30, 90000, 130000, 'เปลี่ยนถังแก๊ส'),
  ('ถ่าน', 0.50, 60000, 120000, ''),
  ('น้ำแข็ง', 1.00, 30000, 60000, ''),
  ('ค่าแรงรายวัน', 0.60, 30000, 60000, 'พนักงานพาร์ทไทม์'),
  ('ของสด/ตลาด', 0.70, 50000, 200000, ''),
  ('ค่าขนส่ง', 0.15, 10000, 30000, ''),
  ('อื่นๆ', 0.15, 5000, 30000, 'ซื้อของจิปาถะ')
) v(name, prob, lo, hi, note);
insert into public.expenses (id, shop_id, business_date, at, type_id, type_name, amount, note)
select pg_temp.uid('exp:' || d.d || ':' || e.name), pg_temp.shop_id(), d.d,
  least(pg_temp.bkk(d.d, 540 + floor(pg_temp.rnd('et:' || d.d || e.name) * 420)::int), now() - interval '1 minute'),
  et.id, e.name, e.lo + floor(pg_temp.rnd('ea:' || d.d || e.name) * ((e.hi - e.lo) / 5000 + 1))::int * 5000, e.note
from t_days d cross join t_exp_def e
join public.expense_types et on et.shop_id = pg_temp.shop_id() and et.name = e.name
where pg_temp.rnd('ep:' || d.d || e.name) < e.prob and pg_temp.bkk(d.d, 540) < now();

-- ============ 8) ซื้อของ + นับสต็อกปิดวัน (จำลองรายวัน: ซื้อถึงเป้า -> ใช้ตามหัว -> นับ) ============
create temp table t_ing on commit drop as
select n, pg_temp.uid('ing:' || n) as id, name, unit, cost, par, sup, uph, freq,
  unit in ('ฟอง', 'ถุง', 'มัด', 'แพ็ค', 'ขวด') as discrete,
  case sup when 1 then array[1, 3, 5, 0] when 2 then array[2, 4, 6] else array[1] end as sched
from t_ing_def;
create temp table t_sim (ing_id uuid primary key, qty numeric not null) on commit drop;
create temp table t_sp (d date, ing_id uuid, qty numeric, total bigint) on commit drop;
create temp table t_sc (d date, ing_id uuid, qty numeric) on commit drop;

do $$
declare
  v_d date;
  v_dow int;
  v_hw numeric;
  v_avg numeric;
  v_today date := pg_temp.today();
begin
  select avg(x.hw) into v_avg
  from (select p.d, sum(p.a + p.c * 0.5) as hw from t_priced p where p.kind <> 'void' and not p.is_today group by p.d) x;
  insert into t_sim select id, par * 2 from t_ing;
  for v_d in select (v_today - g)::date from generate_series(30, 1, -1) g loop
    v_dow := extract(dow from v_d)::int;
    select coalesce(sum(p.a + p.c * 0.5), 0) into v_hw from t_priced p where p.d = v_d and p.kind <> 'void';
    insert into t_sp (d, ing_id, qty, total)
    select v_d, i.id, b.buy, round(b.buy * i.cost * (0.96 + 0.08 * pg_temp.rnd('pc:' || v_d || i.n)))::bigint
    from t_ing i join t_sim s on s.ing_id = i.id
    cross join lateral (
      select greatest(0, v_avg * i.uph * ((select min(((x - v_dow + 6) % 7) + 1) from unnest(i.sched) x) + 2.0) - s.qty) as need
    ) w
    cross join lateral (select case when i.discrete then ceil(w.need) else ceil(w.need * 10) / 10 end as buy) b
    where v_dow = any (i.sched) and b.buy > 0
      -- 3 วันสุดท้ายไม่ซื้อเพิ่มรายการที่จะให้ใกล้หมด/หมด เพื่อให้ของลดลงตามจริง (ไม่ให้ยอดใช้วันล่าสุดพุ่งจนขาดทุน)
      and not (i.n in (5, 8, 10, 15, 17) and v_d >= v_today - 3);
    update t_sim s set qty = s.qty + p.qty from t_sp p where p.d = v_d and p.ing_id = s.ing_id;
    update t_sim s set qty = greatest(0, s.qty - case when i.discrete
        then round(i.uph * v_hw * (0.92 + 0.16 * pg_temp.rnd('us:' || v_d || i.n)))
        else round((i.uph * v_hw * (0.92 + 0.16 * pg_temp.rnd('us:' || v_d || i.n)))::numeric, 1) end)
    from t_ing i where i.id = s.ing_id;
    if v_d = v_today - 1 then
      -- ปิดวันล่าสุด: จงใจให้บางรายการ ใกล้หมด (5, 10, 17) / หมด (8, 15) ที่เหลือไม่ต่ำกว่า par
      update t_sim s set qty = case i.n when 5 then 3 when 10 then 12 when 17 then 3 when 8 then 0 when 15 then 0
                                 else greatest(s.qty, ceil(i.par * 1.1)) end
      from t_ing i where i.id = s.ing_id;
    end if;
    insert into t_sc
    select v_d, s.ing_id, s.qty from t_sim s join t_ing i on i.id = s.ing_id
    where i.freq = 'daily' or v_dow = 1 or v_d = v_today - 1;
  end loop;
end;
$$;

insert into public.purchases (id, shop_id, business_date, at, supplier_id, note)
select pg_temp.uid('pur:' || p.d || ':' || i.sup), pg_temp.shop_id(), p.d, pg_temp.bkk(p.d, 420 + i.sup * 20),
  pg_temp.uid('sup:' || i.sup), 'รับของประจำวัน'
from t_sp p join t_ing i on i.id = p.ing_id group by p.d, i.sup;
insert into public.purchase_lines (shop_id, purchase_id, ingredient_id, qty, total)
select pg_temp.shop_id(), pg_temp.uid('pur:' || p.d || ':' || i.sup), p.ing_id, p.qty, p.total
from t_sp p join t_ing i on i.id = p.ing_id;
insert into public.stock_counts (shop_id, business_date, ingredient_id, qty, counted_at)
select pg_temp.shop_id(), c.d, c.ing_id, c.qty, pg_temp.bkk(c.d, 1430) from t_sc c;

-- ============ 9) วันนี้: 12 โต๊ะมีลูกค้า (เปิดรอบอยู่ ยังไม่คิดเงิน) ============
create temp table t_open on commit drop as
select tb.id as table_id, tb.name as table_name, tb.rk,
  (array[6, 14, 22, 31, 40, 52, 63, 74, 81, 87, 96, 108])[tb.rk::int] as elapsed,
  case tb.rk when 9 then 2 when 10 then 1 when 11 then 1 when 12 then 3
    else case when r.pk < .30 then 1 when r.pk < .65 then 2 when r.pk < .87 then 3 else 4 end end as pkg_idx,
  2 + floor(r.ha * (least(tb.seats, 6) - 2))::int as a,
  case when r.hc < .30 and tb.seats > 4 then 1 else 0 end as c,
  pg_temp.uid('osess:' || tb.name) as session_id,
  case tb.rk when 3 then 'ฉลองวันเกิด ขอเค้ก' when 7 then 'แพ้อาหารทะเล' else '' end as notes
from (
  select t.*, row_number() over (order by md5('open:' || t.name)) as rk
  from public.dining_tables t where t.shop_id = pg_temp.shop_id()
) tb
cross join lateral (select pg_temp.rnd('opk:' || tb.name) pk, pg_temp.rnd('oha:' || tb.name) ha, pg_temp.rnd('ohc:' || tb.name) hc) r
where tb.rk <= 12;

insert into public.table_sessions (id, shop_id, table_id, package_id, opened_at, timing, notes)
select o.session_id, pg_temp.shop_id(), o.table_id, pg_temp.uid('pkg:' || o.pkg_idx),
  now() - o.elapsed * interval '1 minute', 'after', o.notes
from t_open o;

create temp table t_orounds on commit drop as
select o.session_id, o.table_name, o.a, o.c, rn.n as round_no,
  now() - o.elapsed * interval '1 minute' + (array[0, 25, 55])[rn.n] * interval '1 minute' as at_ts
from t_open o
cross join lateral generate_series(1, 3) rn(n)
where rn.n = 1 or (rn.n = 2 and o.elapsed >= 30) or (rn.n = 3 and o.elapsed >= 60);

insert into public.table_rounds (id, shop_id, session_id, at, staff_id, source, heads_a, heads_c, heads_f, addons)
select pg_temp.uid('orn:' || r.session_id || ':' || r.round_no), pg_temp.shop_id(), r.session_id, r.at_ts,
  pg_temp.uid('staff:mali'), 'pos', case when r.round_no = 1 then r.a else 0 end, case when r.round_no = 1 then r.c else 0 end, 0,
  coalesce((
    select jsonb_object_agg(a.id::text, 1 + floor(pg_temp.rnd('oaq:' || r.session_id || r.round_no || a.key) * greatest(1, (r.a + r.c) / 2.0))::int)
    from (select pg_temp.uid('addon:' || key) id, key, prob from t_addon_def) a
    where pg_temp.rnd('oap:' || r.session_id || r.round_no || a.key) < a.prob * case when r.round_no = 1 then 1.2 else 0.8 end
  ), '{}'::jsonb)
from t_orounds r;

commit;

-- Ensure PostgREST queries on the 1,951-bill demo dataset never hit default statement_timeout
alter role authenticated set statement_timeout = '60s';
analyze;
