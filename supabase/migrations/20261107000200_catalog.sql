-- ข้อมูลกลาง + แม่แบบ + ข้อมูลตั้งค่ารายสาขา (docs/backend_plan.md ข้อ 2, 7)
-- ข้อมูลกลางอยู่ใน migration เพราะ `supabase db push` ไม่รัน seed.sql ตามปกติ

create table public.ref_units (
  name text primary key,
  unit_group text not null check (unit_group in ('weight', 'volume', 'count')),
  to_base numeric(12, 3) check (to_base > 0),
  sort_order integer not null,
  check ((unit_group = 'count') = (to_base is null))
);
insert into public.ref_units (name, unit_group, to_base, sort_order) values
  ('กก.', 'weight', 1000, 1), ('ขีด', 'weight', 100, 2), ('กรัม', 'weight', 1, 3),
  ('ลิตร', 'volume', 1000, 4), ('มล.', 'volume', 1, 5),
  ('ชิ้น', 'count', null, 6), ('ฟอง', 'count', null, 7), ('แผง', 'count', null, 8),
  ('แพ็ค', 'count', null, 9), ('ถุง', 'count', null, 10), ('ลัง', 'count', null, 11),
  ('ขวด', 'count', null, 12), ('กระป๋อง', 'count', null, 13), ('แก้ว', 'count', null, 14),
  ('ถัง', 'count', null, 15), ('ถาด', 'count', null, 16), ('กล่อง', 'count', null, 17),
  ('มัด', 'count', null, 18), ('หัว', 'count', null, 19), ('ลูก', 'count', null, 20);

create table public.ref_payment_types (
  code text primary key,
  name text not null,
  sort_order integer not null
);
insert into public.ref_payment_types (code, name, sort_order) values
  ('cash', 'เงินสด', 1), ('qr', 'พร้อมเพย์', 2), ('transfer', 'โอน', 3), ('card', 'บัตร', 4);

create table public.ref_banks (
  name text primary key,
  sort_order integer not null
);
insert into public.ref_banks (name, sort_order) values
  ('กสิกรไทย', 1), ('กรุงเทพ', 2), ('กรุงไทย', 3), ('ไทยพาณิชย์', 4), ('กรุงศรี', 5),
  ('ทีทีบี', 6), ('ออมสิน', 7), ('ธ.ก.ส.', 8), ('ยูโอบี', 9), ('ซีไอเอ็มบี', 10),
  ('แลนด์ แอนด์ เฮ้าส์', 11), ('เกียรตินาคินภัทร', 12), ('ธอส.', 13), ('อิสลาม', 14), ('อื่นๆ', 15);

create table public.ref_system_constants (
  key text primary key,
  value jsonb not null
);
insert into public.ref_system_constants (key, value) values
  ('vat_rate_default', '7'),
  ('day_cutoff_options', '[0, 180, 240, 300, 360]'),
  ('time_limit_options', '[0, 90, 120, 180]');

-- แม่แบบที่คัดลอกเข้าร้านตอนสมัคร
create table public.ref_shop_templates (
  kind text not null check (kind in (
    'ingredient_category', 'addon_category', 'expense_type', 'fixed_cost', 'void_reason', 'payment_method'
  )),
  name text not null,
  sort_order integer not null,
  active boolean not null default true,
  payment_type text references public.ref_payment_types (code),
  primary key (kind, name)
);
insert into public.ref_shop_templates (kind, name, sort_order, active, payment_type) values
  ('ingredient_category', 'เนื้อหมู', 1, true, null),
  ('ingredient_category', 'เนื้อวัว/ไก่', 2, true, null),
  ('ingredient_category', 'อาหารทะเล', 3, true, null),
  ('ingredient_category', 'ผัก', 4, true, null),
  ('ingredient_category', 'น้ำจิ้ม/เครื่องปรุง', 5, true, null),
  ('ingredient_category', 'วัสดุสิ้นเปลือง', 6, true, null),
  ('ingredient_category', 'อื่นๆ', 7, true, null),
  ('addon_category', 'เครื่องดื่ม', 1, true, null),
  ('addon_category', 'ของหวาน', 2, true, null),
  ('addon_category', 'อื่นๆ', 3, true, null),
  ('expense_type', 'แก๊ส', 1, true, null),
  ('expense_type', 'ถ่าน', 2, true, null),
  ('expense_type', 'น้ำแข็ง', 3, true, null),
  ('expense_type', 'ค่าแรงรายวัน', 4, true, null),
  ('expense_type', 'ของสด/ตลาด', 5, true, null),
  ('expense_type', 'ค่าขนส่ง', 6, true, null),
  ('expense_type', 'อื่นๆ', 7, true, null),
  ('fixed_cost', 'ค่าเช่า', 1, false, null),
  ('fixed_cost', 'เงินเดือนพนักงาน', 2, false, null),
  ('fixed_cost', 'ค่าน้ำ', 3, false, null),
  ('fixed_cost', 'ค่าไฟ', 4, false, null),
  ('fixed_cost', 'อินเทอร์เน็ต/แอป', 5, false, null),
  ('fixed_cost', 'ค่าผ่อนอุปกรณ์', 6, false, null),
  ('void_reason', 'คีย์จำนวนคนผิด', 1, true, null),
  ('void_reason', 'เลือกแพ็กเกจผิด', 2, true, null),
  ('void_reason', 'ลูกค้าเปลี่ยนใจ', 3, true, null),
  ('void_reason', 'ชำระเงินผิดช่องทาง', 4, true, null),
  ('void_reason', 'อื่นๆ (ระบุ)', 5, true, null),
  ('payment_method', 'เงินสด', 1, true, 'cash'),
  ('payment_method', 'พร้อมเพย์ QR', 2, true, 'qr'),
  ('payment_method', 'โอนเงิน', 3, false, 'transfer'),
  ('payment_method', 'บัตร', 4, false, 'card');

-- ตั้งค่ารายสาขา: FK แบบ (shop_id, id) กันการอ้างข้อมูลข้ามร้าน

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete restrict,
  kind text not null check (kind in ('ingredient', 'addon')),
  name text not null,
  sort_order integer not null default 0,
  unique (shop_id, kind, name)
);

create table public.dining_tables (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete restrict,
  name text not null,
  seats integer not null check (seats > 0),
  zone text not null default '',
  unique (shop_id, id)
);

create table public.packages (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete restrict,
  name text not null,
  adult_price bigint not null check (adult_price >= 0),
  child_price bigint not null check (child_price >= 0),
  child_rule text not null default '',
  free_rule text not null default '',
  time_limit_min integer not null default 0 check (time_limit_min >= 0),
  active boolean not null default true,
  unique (shop_id, id)
);

create table public.addons (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete restrict,
  name text not null,
  category text not null default '',
  price bigint not null check (price >= 0),
  cost bigint not null check (cost >= 0),
  stock integer not null default 0,
  active boolean not null default true,
  unique (shop_id, id)
);

create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete restrict,
  name text not null,
  phone text not null default '',
  note text not null default '',
  unique (shop_id, id)
);

create table public.ingredients (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete restrict,
  name text not null,
  unit text not null,
  last_cost bigint not null default 0 check (last_cost >= 0),
  par numeric(12, 3) not null default 0 check (par >= 0),
  supplier_id uuid,
  category text not null default '',
  use_per_head numeric(12, 3) not null default 0 check (use_per_head >= 0),
  location text not null default 'dry' check (location in ('fridge', 'freezer', 'dry')),
  count_freq text not null default 'daily' check (count_freq in ('daily', 'weekly')),
  unique (shop_id, id),
  foreign key (shop_id, supplier_id) references public.suppliers (shop_id, id) on delete restrict
);
create index ingredients_supplier_idx on public.ingredients (shop_id, supplier_id);

-- เช่น ไข่: ซื้อเป็นแผง (30 ฟอง) ตัดสต็อกเป็นฟอง
create table public.ingredient_unit_conversions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,
  ingredient_id uuid not null,
  unit text not null,
  factor numeric(12, 3) not null check (factor > 0),
  unique (shop_id, ingredient_id, unit),
  foreign key (shop_id, ingredient_id) references public.ingredients (shop_id, id) on delete cascade
);

create table public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete restrict,
  name text not null,
  type text not null references public.ref_payment_types (code),
  active boolean not null default true,
  unique (shop_id, id)
);
create index payment_methods_type_idx on public.payment_methods (type);

create table public.bank_accounts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete restrict,
  bank_name text not null,
  account_no text not null,
  account_name text not null default '',
  active boolean not null default true,
  unique (shop_id, id)
);

create table public.expense_types (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete restrict,
  name text not null,
  unique (shop_id, id)
);

create table public.fixed_costs (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete restrict,
  name text not null,
  amount bigint not null default 0 check (amount >= 0),
  active boolean not null default true,
  unique (shop_id, id)
);

create table public.void_reasons (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete restrict,
  name text not null,
  sort_order integer not null default 0,
  unique (shop_id, id)
);

create table public.initial_stock (
  shop_id uuid not null,
  ingredient_id uuid not null,
  qty numeric(12, 3) not null check (qty >= 0),
  cost bigint not null check (cost >= 0),
  primary key (shop_id, ingredient_id),
  foreign key (shop_id, ingredient_id) references public.ingredients (shop_id, id) on delete cascade
);
