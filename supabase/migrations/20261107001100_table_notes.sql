-- โน้ตโต๊ะแก้ผ่าน RPC เท่านั้น เพราะบัญชีเครื่องเขียนตารางธุรกรรมตรงไม่ได้
create function public.set_table_notes(p_token text, p_session_id uuid, p_notes text) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
begin
  v_me := private.require_staff_session(p_token);
  update public.table_sessions ts
  set notes = coalesce(trim(p_notes), '')
  where ts.id = p_session_id and ts.shop_id = v_me.shop_id and ts.closed_at is null;
  return found;
end;
$$;

revoke all on function public.set_table_notes(text, uuid, text) from public, anon;
grant execute on function public.set_table_notes(text, uuid, text) to authenticated;
