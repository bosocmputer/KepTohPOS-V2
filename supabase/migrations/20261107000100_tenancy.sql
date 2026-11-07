-- กิจการ -> สาขา -> สมาชิก / เครื่อง / พนักงาน (docs/backend_plan.md ข้อ 2)
-- เงินทุกคอลัมน์เป็นสตางค์ (bigint)

create extension if not exists pgcrypto with schema extensions;

-- schema นี้ไม่ถูก expose ผ่าน PostgREST: ใช้เก็บความลับและ helper
create schema if not exists private;

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  tax_id text check (tax_id ~ '^[0-9]{13}$'),
  vat_registered boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.shops (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete restrict,
  name text not null check (length(trim(name)) > 0),
  branch_code text not null default '00000' check (branch_code ~ '^[0-9]{5}$'),
  branch_name text not null default '',
  address text not null default '',
  phone text not null default '',
  promptpay text not null default '',
  vat_mode text not null default 'none' check (vat_mode in ('none', 'included', 'excluded')),
  vat_rate numeric(5, 2) not null default 7 check (vat_rate >= 0),
  service_pct numeric(5, 2) not null default 0 check (service_pct >= 0),
  default_float bigint not null default 100000 check (default_float >= 0),
  receipt_footer text not null default '',
  use_timer boolean not null default true,
  pay_timing text not null default 'before' check (pay_timing in ('before', 'after')),
  cost_method text not null default 'avg' check (cost_method in ('avg', 'last')),
  show_net_profit boolean not null default true,
  child_head_weight numeric(4, 2) not null default 0.5 check (child_head_weight >= 0),
  open_days_per_month integer not null default 30 check (open_days_per_month between 1 and 31),
  fixed_cost_divisor text not null default 'calendar' check (fixed_cost_divisor in ('calendar', 'custom')),
  weekly_count_dow integer not null default 1 check (weekly_count_dow between 0 and 6),
  day_cutoff_minutes integer not null default 0 check (day_cutoff_minutes between 0 and 1439),
  rounding text not null default 'down' check (rounding in ('down', 'none')),
  theme_mode text not null default 'light',
  theme_palette text not null default 'orange',
  created_at timestamptz not null default now(),
  unique (org_id, id),
  unique (org_id, branch_code)
);

-- shop_id ว่าง = มีสิทธิ์ทุกสาขาในกิจการ
create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  shop_id uuid,
  role text not null check (role in ('owner', 'manager')),
  created_at timestamptz not null default now(),
  unique nulls not distinct (user_id, org_id, shop_id),
  foreign key (org_id, shop_id) references public.shops (org_id, id) on delete cascade,
  check (role <> 'owner' or shop_id is null)
);
create index memberships_org_shop_idx on public.memberships (org_id, shop_id);

-- เครื่อง POS มีบัญชี auth ของตัวเอง (anonymous) ผูกตอนจับคู่
create table public.devices (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete restrict,
  code text not null check (code ~ '^POS[0-9]{2,}$'),
  name text not null check (length(trim(name)) > 0),
  auth_user_id uuid unique references auth.users (id) on delete set null,
  paired_at timestamptz,
  revoked_at timestamptz,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (shop_id, id),
  unique (shop_id, code)
);
create index devices_created_by_idx on public.devices (created_by);

create table private.device_pairings (
  device_id uuid primary key references public.devices (id) on delete cascade,
  code_hash text not null unique,
  expires_at timestamptz not null
);

create table public.staff (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete restrict,
  name text not null check (length(trim(name)) > 0),
  role text not null check (role in ('owner', 'manager', 'cashier')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (shop_id, id)
);

-- แยกจาก staff เพื่อไม่ให้ hash ออกไปกับการอ่านรายชื่อพนักงาน
create table private.staff_pins (
  staff_id uuid primary key references public.staff (id) on delete cascade,
  pin_hash text not null,
  failed_attempts integer not null default 0,
  locked_until timestamptz
);
