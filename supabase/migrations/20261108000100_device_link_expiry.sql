-- ลิงก์เพิ่มเครื่องส่งทาง LINE อาจถูกเปิดหลังจากส่งหลายชั่วโมง จึงขยายอายุรหัสจาก 10 นาทีเป็น 24 ชั่วโมง
-- รหัสยังใช้ได้ครั้งเดียวและเก็บเป็น hash เหมือนเดิม
create or replace function public.create_device_pairing(p_shop_id uuid, p_name text)
returns table (device_id uuid, device_code text, pairing_code text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device_id uuid;
  v_device_code text;
  v_code text := upper(encode(extensions.gen_random_bytes(5), 'hex'));
  v_expires timestamptz := now() + interval '24 hours';
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
