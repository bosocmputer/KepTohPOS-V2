-- ธุรกรรม: id สร้างฝั่งเครื่อง (UUID v7) จึงไม่มี default เพื่อให้ส่งซ้ำแล้วไม่บันทึกซ้ำ
-- รหัสเมนู/โต๊ะ/พนักงานในธุรกรรมเป็นสแนปช็อต ไม่มี FK เพื่อให้ลบข้อมูลตั้งค่าได้โดยประวัติยังอยู่

create table public.shifts (
  id uuid primary key,
  shop_id uuid not null references public.shops (id) on delete restrict,
  device_id uuid not null,
  staff_id uuid not null,
  opened_at timestamptz not null,
  float_amount bigint not null check (float_amount >= 0),
  closed_at timestamptz,
  counted bigint check (counted >= 0),
  closed_by text,
  unique (shop_id, id),
  foreign key (shop_id, device_id) references public.devices (shop_id, id) on delete restrict
);
create index shifts_device_idx on public.shifts (shop_id, device_id);

create table public.table_sessions (
  id uuid primary key,
  shop_id uuid not null references public.shops (id) on delete restrict,
  table_id uuid not null,
  package_id uuid not null,
  opened_at timestamptz not null,
  closed_at timestamptz,
  timing text not null default 'before' check (timing in ('before', 'after')),
  notes text not null default '',
  unique (shop_id, id),
  foreign key (shop_id, table_id) references public.dining_tables (shop_id, id) on delete restrict
);
create index table_sessions_open_idx on public.table_sessions (shop_id, table_id) where closed_at is null;

-- รอบสั่งและการปรับรายการเป็น event เพิ่มอย่างเดียว เครื่องหลายเครื่องจึงไม่เขียนทับกัน
create table public.table_rounds (
  id uuid primary key,
  shop_id uuid not null,
  session_id uuid not null,
  at timestamptz not null,
  staff_id uuid,
  source text not null default 'pos' check (source in ('pos', 'staff', 'qr')),
  heads_a integer not null default 0 check (heads_a >= 0),
  heads_c integer not null default 0 check (heads_c >= 0),
  heads_f integer not null default 0 check (heads_f >= 0),
  addons jsonb not null default '{}' check (jsonb_typeof(addons) = 'object'),
  foreign key (shop_id, session_id) references public.table_sessions (shop_id, id) on delete restrict
);
create index table_rounds_session_idx on public.table_rounds (shop_id, session_id);

create table public.table_adjustments (
  id uuid primary key,
  shop_id uuid not null,
  session_id uuid not null,
  at timestamptz not null,
  by_staff_id uuid,
  by_name text not null default '',
  reason text not null default '',
  kind text not null check (kind in ('head', 'addon')),
  key text not null,
  qty integer not null check (qty > 0),
  foreign key (shop_id, session_id) references public.table_sessions (shop_id, id) on delete restrict
);
create index table_adjustments_session_idx on public.table_adjustments (shop_id, session_id);

create table public.bills (
  id uuid primary key,
  shop_id uuid not null references public.shops (id) on delete restrict,
  device_id uuid not null,
  shift_id uuid,
  session_id uuid,
  no text not null,
  business_date date not null,
  at timestamptz not null,
  table_id uuid,
  table_name text not null default '-',
  staff_id uuid,
  staff_name text not null default '-',
  package_id uuid,
  subtotal bigint not null check (subtotal >= 0),
  service bigint not null default 0 check (service >= 0),
  vat bigint not null default 0 check (vat >= 0),
  rounding bigint not null default 0,
  total bigint not null check (total >= 0),
  heads_a integer not null default 0 check (heads_a >= 0),
  heads_c integer not null default 0 check (heads_c >= 0),
  heads_f integer not null default 0 check (heads_f >= 0),
  method_id uuid,
  method_name text not null default '',
  method_type text not null references public.ref_payment_types (code),
  received bigint not null check (received >= 0),
  change_amount bigint not null default 0 check (change_amount >= 0),
  vat_mode text check (vat_mode in ('none', 'included', 'excluded')),
  vat_rate numeric(5, 2),
  bank_account_id uuid,
  bank_account_info text,
  eat_until timestamptz,
  time_limit_min integer not null default 0 check (time_limit_min >= 0),
  voided boolean not null default false,
  void_reason text,
  void_by text,
  void_at timestamptz,
  created_at timestamptz not null default now(),
  unique (shop_id, id),
  unique (shop_id, no),
  foreign key (shop_id, device_id) references public.devices (shop_id, id) on delete restrict,
  foreign key (shop_id, shift_id) references public.shifts (shop_id, id) on delete restrict,
  foreign key (shop_id, session_id) references public.table_sessions (shop_id, id) on delete restrict,
  check (
    (not voided and void_reason is null and void_by is null and void_at is null)
    or (voided and void_reason is not null and void_by is not null and void_at is not null)
  )
);
create index bills_shop_date_idx on public.bills (shop_id, business_date);
create index bills_device_idx on public.bills (shop_id, device_id);
create index bills_shift_idx on public.bills (shop_id, shift_id);
create index bills_session_idx on public.bills (shop_id, session_id);
create index bills_method_type_idx on public.bills (method_type);

create table public.bill_lines (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,
  bill_id uuid not null,
  line_no integer not null,
  type text not null check (type in ('buffet', 'addon')),
  item_id text,
  name text not null,
  qty integer not null check (qty > 0),
  price bigint not null check (price >= 0),
  cost bigint check (cost >= 0),
  unique (bill_id, line_no),
  foreign key (shop_id, bill_id) references public.bills (shop_id, id) on delete restrict
);
create index bill_lines_bill_idx on public.bill_lines (shop_id, bill_id);

create table public.purchases (
  id uuid primary key,
  shop_id uuid not null references public.shops (id) on delete restrict,
  business_date date not null,
  at timestamptz not null,
  supplier_id uuid,
  note text not null default '',
  unique (shop_id, id)
);
create index purchases_shop_date_idx on public.purchases (shop_id, business_date);

create table public.purchase_lines (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,
  purchase_id uuid not null,
  ingredient_id uuid not null,
  qty numeric(12, 3) not null check (qty > 0),
  total bigint not null check (total >= 0),
  foreign key (shop_id, purchase_id) references public.purchases (shop_id, id) on delete restrict
);
create index purchase_lines_purchase_idx on public.purchase_lines (shop_id, purchase_id);

create table public.expenses (
  id uuid primary key,
  shop_id uuid not null references public.shops (id) on delete restrict,
  business_date date not null,
  at timestamptz not null,
  type_id uuid,
  type_name text not null,
  amount bigint not null check (amount >= 0),
  note text not null default ''
);
create index expenses_shop_date_idx on public.expenses (shop_id, business_date);

create table public.stock_counts (
  shop_id uuid not null references public.shops (id) on delete restrict,
  business_date date not null,
  ingredient_id uuid not null,
  qty numeric(12, 3) not null check (qty >= 0),
  counted_at timestamptz not null,
  primary key (shop_id, business_date, ingredient_id)
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  shop_id uuid not null references public.shops (id) on delete restrict,
  action text not null,
  entity text not null,
  entity_id uuid not null,
  detail jsonb not null default '{}',
  actor_user_id uuid,
  at timestamptz not null default now()
);
create index audit_log_shop_at_idx on public.audit_log (shop_id, at desc);

-- บิลแก้ไม่ได้ ลบไม่ได้ เปลี่ยนได้อย่างเดียวคือยกเลิกครั้งเดียว (แผนข้อ 3.4)
create function private.guard_bill_update() returns trigger
language plpgsql
set search_path = ''
as $$
declare
  void_columns constant text[] := array['voided', 'void_reason', 'void_by', 'void_at'];
begin
  if old.voided then
    raise exception 'bill % is already voided', old.id using errcode = 'P0001';
  end if;
  if not new.voided or (to_jsonb(new) - void_columns) is distinct from (to_jsonb(old) - void_columns) then
    raise exception 'bills are immutable: only voiding is allowed' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create function private.forbid_mutation() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception '% on % is not allowed', tg_op, tg_table_name using errcode = 'P0001';
end;
$$;

-- security definer: ผู้เรียกไม่มีสิทธิ์เขียน audit_log โดยตรง
create function private.audit_bill_void() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.audit_log (shop_id, action, entity, entity_id, detail, actor_user_id)
  values (
    new.shop_id, 'void', 'bill', new.id,
    jsonb_build_object('no', new.no, 'reason', new.void_reason, 'by', new.void_by, 'total', new.total),
    auth.uid()
  );
  return null;
end;
$$;

create trigger bills_guard_update before update on public.bills
  for each row execute function private.guard_bill_update();
create trigger bills_forbid_delete before delete on public.bills
  for each row execute function private.forbid_mutation();
create trigger bills_audit_void after update on public.bills
  for each row execute function private.audit_bill_void();
create trigger bill_lines_append_only before update or delete on public.bill_lines
  for each row execute function private.forbid_mutation();
create trigger table_rounds_append_only before update or delete on public.table_rounds
  for each row execute function private.forbid_mutation();
create trigger table_adjustments_append_only before update or delete on public.table_adjustments
  for each row execute function private.forbid_mutation();
create trigger audit_log_append_only before update or delete on public.audit_log
  for each row execute function private.forbid_mutation();
