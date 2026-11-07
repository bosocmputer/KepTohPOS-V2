-- RPC สมัครร้าน / จับคู่เครื่อง / PIN พนักงาน

-- สมัครร้านใหม่: เจ้าของต้องเป็นบัญชีจริง ไม่ใช่บัญชีเครื่อง (anonymous)
create function public.create_organization_with_shop(
  p_org_name text,
  p_shop_name text,
  p_tax_id text default null,
  p_vat_registered boolean default false,
  p_branch_code text default '00000'
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_org_id uuid;
  v_shop_id uuid;
begin
  if v_uid is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'a full user account is required' using errcode = '42501';
  end if;

  insert into public.organizations (name, tax_id, vat_registered)
  values (p_org_name, p_tax_id, p_vat_registered)
  returning id into v_org_id;

  insert into public.shops (org_id, name, branch_code)
  values (v_org_id, p_shop_name, p_branch_code)
  returning id into v_shop_id;

  insert into public.memberships (user_id, org_id, role)
  values (v_uid, v_org_id, 'owner');

  insert into public.categories (shop_id, kind, name, sort_order)
  select v_shop_id, replace(t.kind, '_category', ''), t.name, t.sort_order
  from public.ref_shop_templates t
  where t.kind in ('ingredient_category', 'addon_category');

  insert into public.expense_types (shop_id, name)
  select v_shop_id, t.name from public.ref_shop_templates t
  where t.kind = 'expense_type' order by t.sort_order;

  insert into public.fixed_costs (shop_id, name, amount, active)
  select v_shop_id, t.name, 0, t.active from public.ref_shop_templates t
  where t.kind = 'fixed_cost' order by t.sort_order;

  insert into public.void_reasons (shop_id, name, sort_order)
  select v_shop_id, t.name, t.sort_order from public.ref_shop_templates t
  where t.kind = 'void_reason';

  insert into public.payment_methods (shop_id, name, type, active)
  select v_shop_id, t.name, t.payment_type, t.active from public.ref_shop_templates t
  where t.kind = 'payment_method' order by t.sort_order;

  return v_shop_id;
end;
$$;

-- เจ้าของ/ผู้จัดการออกรหัสจับคู่ใช้ครั้งเดียว อายุ 10 นาที
create function public.create_device_pairing(p_shop_id uuid, p_name text)
returns table (device_id uuid, device_code text, pairing_code text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device_id uuid;
  v_device_code text;
  v_code text := upper(encode(extensions.gen_random_bytes(5), 'hex'));
  v_expires timestamptz := now() + interval '10 minutes';
begin
  if not private.can_manage_shop(p_shop_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  -- นับรวมเครื่องที่ถูกเพิกถอน เพื่อไม่ให้รหัสเครื่องและชุดเลขใบเสร็จถูกใช้ซ้ำ
  select 'POS' || lpad((count(*) + 1)::text, 2, '0') into v_device_code
  from public.devices d where d.shop_id = p_shop_id;

  insert into public.devices (shop_id, code, name, created_by)
  values (p_shop_id, v_device_code, p_name, auth.uid())
  returning id into v_device_id;

  insert into private.device_pairings (device_id, code_hash, expires_at)
  values (v_device_id, encode(extensions.digest(v_code, 'sha256'), 'hex'), v_expires);

  return query select v_device_id, v_device_code, v_code, v_expires;
end;
$$;

-- เรียกจากเครื่องหลัง signInAnonymously() เพื่อผูกบัญชีเครื่องเข้ากับสาขา
create function public.claim_device(p_pairing_code text)
returns table (device_id uuid, shop_id uuid, device_code text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_device_id uuid;
begin
  if v_uid is null or not coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'a device account is required' using errcode = '42501';
  end if;
  if exists (select 1 from public.devices d where d.auth_user_id = v_uid) then
    raise exception 'this account is already paired' using errcode = '42501';
  end if;

  delete from private.device_pairings p
  where p.code_hash = encode(extensions.digest(upper(trim(p_pairing_code)), 'sha256'), 'hex')
    and p.expires_at > now()
  returning p.device_id into v_device_id;

  if v_device_id is null then
    raise exception 'invalid or expired pairing code' using errcode = 'P0002';
  end if;

  return query
  update public.devices d
  set auth_user_id = v_uid, paired_at = now()
  where d.id = v_device_id and d.revoked_at is null
  returning d.id, d.shop_id, d.code;
end;
$$;

create function public.set_staff_pin(p_staff_id uuid, p_pin text) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_shop_id uuid;
begin
  select s.shop_id into v_shop_id from public.staff s where s.id = p_staff_id;
  if v_shop_id is null or not private.can_manage_shop(v_shop_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_pin !~ '^[0-9]{4}$' then
    raise exception 'PIN must be 4 digits' using errcode = '22023';
  end if;

  insert into private.staff_pins (staff_id, pin_hash)
  values (p_staff_id, extensions.crypt(p_pin, extensions.gen_salt('bf')))
  on conflict (staff_id) do update
    set pin_hash = excluded.pin_hash, failed_attempts = 0, locked_until = null;
end;
$$;

-- ผิดครบ 5 ครั้งล็อก 5 นาที
-- คืนผลเป็น jsonb แทน raise เพราะ raise จะ rollback ตัวนับครั้งที่ผิด
create function public.verify_staff_pin(p_staff_id uuid, p_pin text) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_staff public.staff;
  v_pin private.staff_pins;
  v_max_attempts constant integer := 5;
begin
  select * into v_staff from public.staff s where s.id = p_staff_id and s.active;
  if v_staff.id is null or not private.can_read_shop(v_staff.shop_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  -- for update: คำขอพร้อมกันต้องนับครั้งที่ผิดครบทุกครั้ง
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
    return jsonb_build_object('ok', true, 'staff_id', v_staff.id, 'name', v_staff.name, 'role', v_staff.role);
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

revoke all on function public.create_organization_with_shop(text, text, text, boolean, text) from public, anon;
revoke all on function public.create_device_pairing(uuid, text) from public, anon;
revoke all on function public.claim_device(text) from public, anon;
revoke all on function public.set_staff_pin(uuid, text) from public, anon;
revoke all on function public.verify_staff_pin(uuid, text) from public, anon;

grant execute on function public.create_organization_with_shop(text, text, text, boolean, text) to authenticated;
grant execute on function public.create_device_pairing(uuid, text) to authenticated;
grant execute on function public.claim_device(text) to authenticated;
grant execute on function public.set_staff_pin(uuid, text) to authenticated;
grant execute on function public.verify_staff_pin(uuid, text) to authenticated;
