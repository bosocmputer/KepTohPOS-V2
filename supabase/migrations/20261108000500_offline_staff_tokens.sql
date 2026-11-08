-- ขายตอนออฟไลน์ (M2): token ออฟไลน์อายุ 7 วันต่อพนักงานต่อเครื่อง
-- ใช้กับคำสั่งที่เข้าคิวตอนเน็ตหลุด และให้เครื่องตรวจ PIN เองได้ภายใน 7 วัน
-- เก็บเฉพาะ hash เหมือน staff_sessions; ไม่แทนที่ token เก่า เพราะคำสั่งในคิวอาจยังใช้อยู่
create table private.staff_offline_tokens (
  token_hash text primary key,
  staff_id uuid not null references public.staff (id) on delete cascade,
  device_id uuid not null references public.devices (id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index staff_offline_tokens_staff_device_idx on private.staff_offline_tokens (staff_id, device_id);
create index staff_offline_tokens_device_idx on private.staff_offline_tokens (device_id);
revoke all on private.staff_offline_tokens from public, anon, authenticated;

create or replace function private.require_staff_session(
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

  -- คำสั่งที่ทำตอนออฟไลน์ส่งมาพร้อม token ออฟไลน์ (7 วัน) ของพนักงานคนนั้นบนเครื่องนั้น
  -- จึงยังใช้ได้แม้มีคนอื่นเข้าสู่ระบบบนเครื่องเดียวกันแล้ว
  if staff_id is null then
    select s.id, s.name, s.role, d.id, d.shop_id
    into staff_id, staff_name, staff_role, device_id, shop_id
    from private.staff_offline_tokens ot
    join public.staff s on s.id = ot.staff_id and s.active
    join public.devices d on d.id = ot.device_id and d.revoked_at is null
    where ot.token_hash = private.hash_token(p_token)
      and ot.expires_at > now()
      and d.auth_user_id = auth.uid()
      and d.shop_id = s.shop_id;
  end if;

  if staff_id is null then
    raise exception 'staff session is invalid or expired' using errcode = '42501';
  end if;
end;
$$;

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
  v_offline text;
  v_offline_expires timestamptz := now() + interval '7 days';
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
      v_offline := encode(extensions.gen_random_bytes(32), 'hex');
      delete from private.staff_offline_tokens ot
      where ot.staff_id = p_staff_id and ot.device_id = v_device_id and ot.expires_at <= now();
      insert into private.staff_offline_tokens (token_hash, staff_id, device_id, expires_at)
      values (private.hash_token(v_offline), p_staff_id, v_device_id, v_offline_expires);
      v_result := v_result || jsonb_build_object(
        'session_token', v_token, 'expires_at', v_expires,
        'offline_token', v_offline, 'offline_expires_at', v_offline_expires
      );
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
