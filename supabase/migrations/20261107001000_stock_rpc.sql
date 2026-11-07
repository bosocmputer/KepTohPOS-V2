-- RPC การซื้อ ค่าใช้จ่าย และการนับสต็อก: กติกาตรงกับ stock_ops.dart และ stock_balance_ops.dart
-- แคชเชียร์เพิ่มรายการใหม่ได้ แต่แก้ไข/ลบ/เปิดวันที่ปิดแล้วต้องเป็นเจ้าของหรือผู้จัดการ

create function private.require_manager(p_role text) returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_role = 'cashier' then
    raise exception 'manager or owner is required' using errcode = '42501';
  end if;
end;
$$;

-- ทุกรายการต้องอ้างวัตถุดิบของร้านนี้ และจำนวน/ยอดต้องถูกต้อง
create function private.validate_purchase_lines(p_shop_id uuid, p_lines jsonb) returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 or exists (
    select 1
    from jsonb_array_elements(p_lines) l
    left join public.ingredients i on i.shop_id = p_shop_id and i.id = (l ->> 'ingredient_id')::uuid
    where i.id is null or (l ->> 'qty')::numeric <= 0 or (l ->> 'total')::bigint < 0
  ) then
    raise exception 'invalid purchase lines' using errcode = '22023';
  end if;
end;
$$;

-- p_is_edit = false: ส่งซ้ำด้วย id เดิมไม่บันทึกซ้ำ
create function public.record_purchase(
  p_token text,
  p_id uuid,
  p_date date,
  p_supplier_id uuid,
  p_note text,
  p_lines jsonb,
  p_at timestamptz,
  p_is_edit boolean default false
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
  v_exists boolean;
begin
  v_me := private.require_staff_session(p_token);
  perform private.validate_purchase_lines(v_me.shop_id, p_lines);

  if p_supplier_id is not null and not exists (
    select 1 from public.suppliers s where s.id = p_supplier_id and s.shop_id = v_me.shop_id
  ) then
    raise exception 'unknown supplier' using errcode = '22023';
  end if;

  select exists (select 1 from public.purchases p where p.id = p_id and p.shop_id = v_me.shop_id) into v_exists;

  if p_is_edit then
    perform private.require_manager(v_me.staff_role);
    if not v_exists then
      return false;
    end if;
    update public.purchases p
    set business_date = p_date, supplier_id = p_supplier_id, note = coalesce(trim(p_note), '')
    where p.id = p_id;
    delete from public.purchase_lines l where l.shop_id = v_me.shop_id and l.purchase_id = p_id;
  elsif v_exists then
    return true;
  else
    insert into public.purchases (id, shop_id, business_date, at, supplier_id, note)
    values (p_id, v_me.shop_id, p_date, p_at, p_supplier_id, coalesce(trim(p_note), ''));
  end if;

  insert into public.purchase_lines (shop_id, purchase_id, ingredient_id, qty, total)
  select v_me.shop_id, p_id, (l ->> 'ingredient_id')::uuid, (l ->> 'qty')::numeric, (l ->> 'total')::bigint
  from jsonb_array_elements(p_lines) l;

  return true;
end;
$$;

create function public.remove_purchase(p_token text, p_id uuid) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
begin
  v_me := private.require_staff_session(p_token);
  perform private.require_manager(v_me.staff_role);

  delete from public.purchase_lines l where l.shop_id = v_me.shop_id and l.purchase_id = p_id;
  delete from public.purchases p where p.id = p_id and p.shop_id = v_me.shop_id;
  return found;
end;
$$;

-- p_lines: [{id, type_id, amount, note}] โดย id มาจากเครื่อง ส่งซ้ำจึงไม่บันทึกซ้ำ
create function public.record_expenses(
  p_token text,
  p_date date,
  p_lines jsonb,
  p_at timestamptz
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
begin
  v_me := private.require_staff_session(p_token);

  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 or exists (
    select 1
    from jsonb_array_elements(p_lines) l
    left join public.expense_types t on t.shop_id = v_me.shop_id and t.id = (l ->> 'type_id')::uuid
    where t.id is null or (l ->> 'amount')::bigint <= 0
  ) then
    raise exception 'invalid expense lines' using errcode = '22023';
  end if;

  insert into public.expenses (id, shop_id, business_date, at, type_id, type_name, amount, note)
  select (l ->> 'id')::uuid, v_me.shop_id, p_date, p_at, t.id, t.name, (l ->> 'amount')::bigint, coalesce(trim(l ->> 'note'), '')
  from jsonb_array_elements(p_lines) l
  join public.expense_types t on t.shop_id = v_me.shop_id and t.id = (l ->> 'type_id')::uuid
  on conflict (id) do nothing;

  return true;
end;
$$;

create function public.update_expense(
  p_token text,
  p_id uuid,
  p_type_id uuid,
  p_amount bigint,
  p_note text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
  v_type_name text;
begin
  v_me := private.require_staff_session(p_token);
  perform private.require_manager(v_me.staff_role);

  select t.name into v_type_name from public.expense_types t
  where t.id = p_type_id and t.shop_id = v_me.shop_id;
  if v_type_name is null or p_amount <= 0 then
    raise exception 'invalid expense' using errcode = '22023';
  end if;

  update public.expenses e
  set type_id = p_type_id, type_name = v_type_name, amount = p_amount, note = coalesce(trim(p_note), '')
  where e.id = p_id and e.shop_id = v_me.shop_id;
  return found;
end;
$$;

create function public.remove_expense(p_token text, p_id uuid) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
begin
  v_me := private.require_staff_session(p_token);
  perform private.require_manager(v_me.staff_role);

  delete from public.expenses e where e.id = p_id and e.shop_id = v_me.shop_id;
  return found;
end;
$$;

-- บันทึกยอดนับแทนที่ของเดิมทั้งวัน p_counts: {ingredient_id: qty}
create function public.save_stock_count(
  p_token text,
  p_date date,
  p_counts jsonb,
  p_at timestamptz
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
begin
  v_me := private.require_staff_session(p_token);

  if jsonb_typeof(p_counts) <> 'object' or p_counts = '{}' or exists (
    select 1
    from jsonb_each_text(p_counts) c
    left join public.ingredients i on i.shop_id = v_me.shop_id and i.id = c.key::uuid
    where i.id is null or c.value::numeric < 0
  ) then
    raise exception 'invalid stock count' using errcode = '22023';
  end if;

  delete from public.stock_counts sc where sc.shop_id = v_me.shop_id and sc.business_date = p_date;
  insert into public.stock_counts (shop_id, business_date, ingredient_id, qty, counted_at)
  select v_me.shop_id, p_date, c.key::uuid, c.value::numeric, p_at
  from jsonb_each_text(p_counts) c;
end;
$$;

create function public.reopen_day(p_token text, p_date date) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
begin
  v_me := private.require_staff_session(p_token);
  perform private.require_manager(v_me.staff_role);

  delete from public.stock_counts sc where sc.shop_id = v_me.shop_id and sc.business_date = p_date;
  return found;
end;
$$;

revoke all on function private.require_manager(text) from public, anon, authenticated;
revoke all on function private.validate_purchase_lines(uuid, jsonb) from public, anon, authenticated;

revoke all on function public.record_purchase(text, uuid, date, uuid, text, jsonb, timestamptz, boolean) from public, anon;
revoke all on function public.remove_purchase(text, uuid) from public, anon;
revoke all on function public.record_expenses(text, date, jsonb, timestamptz) from public, anon;
revoke all on function public.update_expense(text, uuid, uuid, bigint, text) from public, anon;
revoke all on function public.remove_expense(text, uuid) from public, anon;
revoke all on function public.save_stock_count(text, date, jsonb, timestamptz) from public, anon;
revoke all on function public.reopen_day(text, date) from public, anon;

grant execute on function public.record_purchase(text, uuid, date, uuid, text, jsonb, timestamptz, boolean) to authenticated;
grant execute on function public.remove_purchase(text, uuid) to authenticated;
grant execute on function public.record_expenses(text, date, jsonb, timestamptz) to authenticated;
grant execute on function public.update_expense(text, uuid, uuid, bigint, text) to authenticated;
grant execute on function public.remove_expense(text, uuid) to authenticated;
grant execute on function public.save_stock_count(text, date, jsonb, timestamptz) to authenticated;
grant execute on function public.reopen_day(text, date) to authenticated;
