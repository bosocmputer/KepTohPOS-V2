-- ค่าเริ่มต้นของ Supabase ให้ anon/authenticated ทำได้ทุกอย่าง รวมถึง TRUNCATE ที่ RLS กันไม่ได้
-- จึงถอนทั้งหมดแล้วให้สิทธิ์เฉพาะที่ต้องใช้
revoke all on all tables in schema public from anon, authenticated;
revoke all on all routines in schema public from public, anon, authenticated;
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on routines from public, anon, authenticated;

revoke all on all routines in schema private from public;
alter default privileges for role postgres in schema private revoke all on routines from public;

grant usage on schema private to authenticated;

create function private.can_manage_shop(p_shop_id uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships m
    join public.shops s on s.org_id = m.org_id
    where s.id = p_shop_id
      and m.user_id = auth.uid()
      and (m.shop_id is null or m.shop_id = p_shop_id)
  );
$$;

create function private.is_active_device_of(p_shop_id uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.devices d
    where d.shop_id = p_shop_id
      and d.auth_user_id = auth.uid()
      and d.revoked_at is null
  );
$$;

create function private.can_read_shop(p_shop_id uuid) returns boolean
language sql
stable
set search_path = ''
as $$
  select private.can_manage_shop(p_shop_id) or private.is_active_device_of(p_shop_id);
$$;

create function private.is_org_owner(p_org_id uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.memberships m
    where m.org_id = p_org_id and m.user_id = auth.uid() and m.role = 'owner'
  );
$$;

create function private.can_read_org(p_org_id uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.memberships m
    where m.org_id = p_org_id and m.user_id = auth.uid()
  ) or exists (
    select 1 from public.devices d
    join public.shops s on s.id = d.shop_id
    where s.org_id = p_org_id and d.auth_user_id = auth.uid() and d.revoked_at is null
  );
$$;

grant execute on function private.can_manage_shop(uuid) to authenticated;
grant execute on function private.is_active_device_of(uuid) to authenticated;
grant execute on function private.can_read_shop(uuid) to authenticated;
grant execute on function private.is_org_owner(uuid) to authenticated;
grant execute on function private.can_read_org(uuid) to authenticated;

-- เปิด RLS ทุกตารางใน public (ตารางไหนไม่มี policy = ปฏิเสธทั้งหมด)
do $$
declare
  t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end;
$$;

-- ข้อมูลกลาง: อ่านอย่างเดียว
do $$
declare
  t text;
begin
  foreach t in array array['ref_units', 'ref_payment_types', 'ref_banks', 'ref_system_constants', 'ref_shop_templates'] loop
    execute format('grant select on public.%I to authenticated', t);
    execute format('create policy ref_read on public.%I for select to authenticated using (true)', t);
  end loop;
end;
$$;

-- ตั้งค่ารายสาขา: อ่านได้ทั้งเจ้าของ/ผู้จัดการ/เครื่อง แต่แก้ได้เฉพาะเจ้าของ/ผู้จัดการ
do $$
declare
  t text;
begin
  foreach t in array array[
    'staff', 'categories', 'dining_tables', 'packages', 'addons', 'suppliers', 'ingredients',
    'ingredient_unit_conversions', 'payment_methods', 'bank_accounts', 'expense_types',
    'fixed_costs', 'void_reasons', 'initial_stock'
  ] loop
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('create policy shop_read on public.%I for select to authenticated using ((select private.can_read_shop(shop_id)))', t);
    execute format('create policy shop_insert on public.%I for insert to authenticated with check ((select private.can_manage_shop(shop_id)))', t);
    execute format('create policy shop_update on public.%I for update to authenticated using ((select private.can_manage_shop(shop_id))) with check ((select private.can_manage_shop(shop_id)))', t);
    execute format('create policy shop_delete on public.%I for delete to authenticated using ((select private.can_manage_shop(shop_id)))', t);
  end loop;
end;
$$;

-- ธุรกรรม: อ่านได้อย่างเดียว การเขียนทำผ่าน RPC เท่านั้น (settle_bill ฯลฯ ใน F1)
do $$
declare
  t text;
begin
  foreach t in array array[
    'shifts', 'table_sessions', 'table_rounds', 'table_adjustments', 'bills', 'bill_lines',
    'purchases', 'purchase_lines', 'expenses', 'stock_counts'
  ] loop
    execute format('grant select on public.%I to authenticated', t);
    execute format('create policy shop_read on public.%I for select to authenticated using ((select private.can_read_shop(shop_id)))', t);
  end loop;
end;
$$;

grant select on public.audit_log to authenticated;
create policy audit_read on public.audit_log for select to authenticated
  using ((select private.can_manage_shop(shop_id)));

grant select on public.organizations to authenticated;
grant update (name, tax_id, vat_registered) on public.organizations to authenticated;
create policy org_read on public.organizations for select to authenticated
  using ((select private.can_read_org(id)));
create policy org_update on public.organizations for update to authenticated
  using ((select private.is_org_owner(id))) with check ((select private.is_org_owner(id)));

grant select on public.shops to authenticated;
grant update (
  name, branch_name, address, phone, promptpay, vat_mode, vat_rate, service_pct, default_float,
  receipt_footer, use_timer, pay_timing, cost_method, show_net_profit, child_head_weight,
  open_days_per_month, fixed_cost_divisor, weekly_count_dow, day_cutoff_minutes, rounding,
  theme_mode, theme_palette
) on public.shops to authenticated;
create policy shop_read on public.shops for select to authenticated
  using ((select private.can_read_shop(id)));
create policy shop_update on public.shops for update to authenticated
  using ((select private.can_manage_shop(id))) with check ((select private.can_manage_shop(id)));

grant select on public.memberships to authenticated;
create policy membership_read on public.memberships for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_org_owner(org_id)));

grant select on public.devices to authenticated;
grant update (name, revoked_at) on public.devices to authenticated;
create policy device_read on public.devices for select to authenticated
  using ((select private.can_read_shop(shop_id)));
create policy device_update on public.devices for update to authenticated
  using ((select private.can_manage_shop(shop_id))) with check ((select private.can_manage_shop(shop_id)));
