-- สัญญาณ "ข้อมูลร้านเปลี่ยน" ผ่าน Realtime Broadcast (private channel shop:<shop_id>)
-- ส่งแค่ชื่อตาราง ไม่มีข้อมูลแถว เครื่องรับสัญญาณแล้วโหลดข้อมูลใหม่เอง

create function private.signal_shop_changed() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  s uuid;
begin
  -- ระดับ statement: ส่งหนึ่งครั้งต่อร้านต่อคำสั่ง ไม่ใช่ต่อแถว
  for s in select distinct shop_id from changed_rows loop
    perform realtime.send(jsonb_build_object('table', tg_table_name), 'changed', 'shop:' || s, true);
  end loop;
  return null;
end;
$$;
revoke all on function private.signal_shop_changed() from public, anon, authenticated;

do $$
declare
  t text;
begin
  foreach t in array array[
    'table_sessions', 'table_rounds', 'table_adjustments', 'bills', 'bill_lines', 'shifts', 'dining_tables'
  ] loop
    execute format(
      'create trigger signal_ins after insert on public.%I referencing new table as changed_rows
         for each statement execute function private.signal_shop_changed()', t);
    execute format(
      'create trigger signal_upd after update on public.%I referencing new table as changed_rows
         for each statement execute function private.signal_shop_changed()', t);
  end loop;
end;
$$;

-- อ่านสัญญาณได้เฉพาะ topic ของร้านที่ตัวเองอ่านได้ (เจ้าของ/ผู้จัดการ หรือเครื่องที่ยังไม่ถูกเพิกถอน)
-- ไม่มี policy insert = client ส่ง broadcast เองไม่ได้
create policy shop_signal_read on realtime.messages
for select to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and case
    when (select realtime.topic()) ~ '^shop:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then (select private.can_read_shop(substr((select realtime.topic()), 6)::uuid))
    else false
  end
);
