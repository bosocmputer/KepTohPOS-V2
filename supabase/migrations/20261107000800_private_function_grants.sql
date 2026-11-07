-- `alter default privileges ... in schema` ใน 000400 ถอน EXECUTE ที่ให้ PUBLIC โดยอัตโนมัติไม่ได้
-- จึงถอนตรง ๆ ฟังก์ชันที่เพิ่มใน private ภายหลังต้องถอนเองเช่นกัน (มีเทสต์ใน rls_test.sql ตรวจอยู่)
revoke all on all routines in schema private from public, anon, authenticated;

grant execute on function private.can_manage_shop(uuid) to authenticated;
grant execute on function private.is_active_device_of(uuid) to authenticated;
grant execute on function private.can_read_shop(uuid) to authenticated;
grant execute on function private.is_org_owner(uuid) to authenticated;
grant execute on function private.can_read_org(uuid) to authenticated;
