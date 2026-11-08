-- เจ้าของสั่ง "ออกจากร้านบนเครื่องนี้" จากเครื่องนั้นเอง: เครื่องยกเลิกการจับคู่ของตัวเองได้ แต่แตะเครื่องอื่นไม่ได้
create function public.leave_device()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'a device account is required' using errcode = '42501';
  end if;
  update public.devices
  set revoked_at = now()
  where auth_user_id = auth.uid() and revoked_at is null;
end;
$$;

revoke all on function public.leave_device() from public, anon;
grant execute on function public.leave_device() to authenticated;
