-- Session พนักงานหลังตรวจ PIN + ปิดข้อมูลต้นทุนจากบัญชีเครื่อง

-- เก็บเฉพาะ hash ของ token และให้ 1 เครื่องมี session เดียว (สลับคน = session เก่าหมดอายุ)
create table private.staff_sessions (
  id uuid primary key default gen_random_uuid(),
  token_hash text not null unique,
  staff_id uuid not null references public.staff (id) on delete cascade,
  device_id uuid not null unique references public.devices (id) on delete cascade,
  expires_at timestamptz not null
);
create index staff_sessions_staff_idx on private.staff_sessions (staff_id);

create function private.hash_token(p_token text) returns text
language sql
immutable
set search_path = ''
as $$
  select encode(extensions.digest(p_token, 'sha256'), 'hex');
$$;

-- token ต้องใช้จากเครื่องเดิมที่ออกให้ และพนักงาน/เครื่องต้องยังใช้งานได้
create function private.require_staff_session(
  p_token text,
  out staff_id uuid,
  out staff_name text,
  out staff_role text,
  out device_id uuid,
  out shop_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  select s.id, s.name, s.role, d.id, d.shop_id
  into staff_id, staff_name, staff_role, device_id, shop_id
  from private.staff_sessions ss
  join public.staff s on s.id = ss.staff_id and s.active
  join public.devices d on d.id = ss.device_id and d.revoked_at is null
  where ss.token_hash = private.hash_token(p_token)
    and ss.expires_at > now()
    and d.auth_user_id = auth.uid()
    and d.shop_id = s.shop_id;

  if staff_id is null then
    raise exception 'staff session is invalid or expired' using errcode = '42501';
  end if;
end;
$$;

-- เหมือน migration 000500 แต่เพิ่มการออก session เมื่อเรียกจากเครื่องที่จับคู่แล้ว
create or replace function public.verify_staff_pin(p_staff_id uuid, p_pin text) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_staff public.staff;
  v_pin private.staff_pins;
  v_max_attempts constant integer := 5;
  v_device_id uuid;
  v_token text;
  v_expires timestamptz := now() + interval '12 hours';
  v_result jsonb;
begin
  select * into v_staff from public.staff s where s.id = p_staff_id and s.active;
  if v_staff.id is null or not private.can_read_shop(v_staff.shop_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  select * into v_pin from private.staff_pins p where p.staff_id = p_staff_id for update;
  if v_pin.staff_id is null then
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;

  if v_pin.locked_until > now() then
    return jsonb_build_object('ok', false, 'reason', 'locked', 'locked_until', v_pin.locked_until);
  end if;

  if v_pin.pin_hash = extensions.crypt(p_pin, v_pin.pin_hash) then
    update private.staff_pins p set failed_attempts = 0, locked_until = null
    where p.staff_id = p_staff_id;

    v_result := jsonb_build_object('ok', true, 'staff_id', v_staff.id, 'name', v_staff.name, 'role', v_staff.role);

    select d.id into v_device_id from public.devices d
    where d.auth_user_id = auth.uid() and d.shop_id = v_staff.shop_id and d.revoked_at is null;

    if v_device_id is not null then
      v_token := encode(extensions.gen_random_bytes(32), 'hex');
      insert into private.staff_sessions (token_hash, staff_id, device_id, expires_at)
      values (private.hash_token(v_token), p_staff_id, v_device_id, v_expires)
      on conflict (device_id) do update
        set token_hash = excluded.token_hash, staff_id = excluded.staff_id, expires_at = excluded.expires_at;
      v_result := v_result || jsonb_build_object('session_token', v_token, 'expires_at', v_expires);
    end if;

    return v_result;
  end if;

  if v_pin.failed_attempts + 1 >= v_max_attempts then
    update private.staff_pins p
    set failed_attempts = 0, locked_until = now() + interval '5 minutes'
    where p.staff_id = p_staff_id
    returning p.locked_until into v_pin.locked_until;
    return jsonb_build_object('ok', false, 'reason', 'locked', 'locked_until', v_pin.locked_until);
  end if;

  update private.staff_pins p set failed_attempts = p.failed_attempts + 1
  where p.staff_id = p_staff_id;
  return jsonb_build_object(
    'ok', false, 'reason', 'invalid', 'attempts_left', v_max_attempts - v_pin.failed_attempts - 1
  );
end;
$$;

create function public.end_staff_session(p_token text) returns void
language sql
security definer
set search_path = ''
as $$
  delete from private.staff_sessions ss
  using public.devices d
  where d.id = ss.device_id
    and d.auth_user_id = auth.uid()
    and ss.token_hash = private.hash_token(p_token);
$$;

-- ตารางที่มีแต่ข้อมูลต้นทุน: เครื่องอ่านตรงไม่ได้
do $$
declare
  t text;
begin
  foreach t in array array['fixed_costs', 'initial_stock', 'expenses', 'purchases', 'purchase_lines'] loop
    execute format('drop policy shop_read on public.%I', t);
    execute format(
      'create policy shop_read on public.%I for select to authenticated using ((select private.can_manage_shop(shop_id)))', t
    );
  end loop;
end;
$$;

-- คอลัมน์ต้นทุน: เจ้าของกับเครื่องใช้ role เดียวกัน จึงปิดคอลัมน์สำหรับทุกคน แล้วอ่านผ่าน get_manager_data
revoke select on public.addons, public.ingredients, public.bill_lines from authenticated;
grant select (id, shop_id, name, category, price, stock, active) on public.addons to authenticated;
grant select (id, shop_id, name, unit, par, supplier_id, category, use_per_head, location, count_freq)
  on public.ingredients to authenticated;
grant select (id, shop_id, bill_id, line_no, type, item_id, name, qty, price) on public.bill_lines to authenticated;

-- ข้อมูลภาพรวม/รายงาน: เจ้าของหรือผู้จัดการ (บัญชีจริง หรือ PIN บนเครื่องของสาขานั้น)
create function public.get_manager_data(
  p_shop_id uuid,
  p_from date,
  p_to date,
  p_token text default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_session record;
begin
  if not private.can_manage_shop(p_shop_id) then
    if p_token is null then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    v_session := private.require_staff_session(p_token);
    if v_session.shop_id <> p_shop_id or v_session.staff_role not in ('owner', 'manager') then
      raise exception 'not allowed' using errcode = '42501';
    end if;
  end if;

  return jsonb_build_object(
    'addon_costs', (
      select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'cost', a.cost)), '[]')
      from public.addons a where a.shop_id = p_shop_id
    ),
    'ingredient_costs', (
      select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'last_cost', i.last_cost)), '[]')
      from public.ingredients i where i.shop_id = p_shop_id
    ),
    'fixed_costs', (
      select coalesce(jsonb_agg(to_jsonb(f)), '[]') from public.fixed_costs f where f.shop_id = p_shop_id
    ),
    'initial_stock', (
      select coalesce(jsonb_agg(to_jsonb(s)), '[]') from public.initial_stock s where s.shop_id = p_shop_id
    ),
    'expenses', (
      select coalesce(jsonb_agg(to_jsonb(e)), '[]') from public.expenses e
      where e.shop_id = p_shop_id and e.business_date between p_from and p_to
    ),
    'purchases', (
      select coalesce(jsonb_agg(
        to_jsonb(p) || jsonb_build_object('lines', (
          select coalesce(jsonb_agg(to_jsonb(l)), '[]') from public.purchase_lines l
          where l.shop_id = p.shop_id and l.purchase_id = p.id
        ))
      ), '[]')
      from public.purchases p
      where p.shop_id = p_shop_id and p.business_date between p_from and p_to
    ),
    'bill_line_costs', (
      select coalesce(jsonb_agg(jsonb_build_object('bill_id', l.bill_id, 'line_no', l.line_no, 'cost', l.cost)), '[]')
      from public.bill_lines l
      join public.bills b on b.shop_id = l.shop_id and b.id = l.bill_id
      where b.shop_id = p_shop_id and b.business_date between p_from and p_to and l.cost is not null
    )
  );
end;
$$;

revoke all on function public.end_staff_session(text) from public, anon;
revoke all on function public.get_manager_data(uuid, date, date, text) from public, anon;
grant execute on function public.end_staff_session(text) to authenticated;
grant execute on function public.get_manager_data(uuid, date, date, text) to authenticated;
