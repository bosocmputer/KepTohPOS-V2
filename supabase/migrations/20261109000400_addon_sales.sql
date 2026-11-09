-- ยอดขายของเพิ่มเติม (addon) รายวัน x ชื่อสินค้า ฝั่งฐานข้อมูล (แอปกรองตามช่วงของ dashboard เอง)
-- ตรงกับ addonAgg ใน app/lib/domain/dashboard_reports_ops.dart: รวมตามชื่อ
-- รวมตามวัน+ชื่อ rev = sum(qty * price) (ไม่คูณ k2), cost = sum(qty * cost) ; บิลยกเลิกไม่นับ
-- cost เป็น NULL เว้นแต่ผู้เรียกมีสิทธิ์เห็นต้นทุน (กฎเดียวกับ get_daily_sales_totals)
create or replace function public.get_addon_sales(
  p_shop_id uuid,
  p_from date,
  p_to date,
  p_token text default null
) returns table (
  business_date date,
  name text,
  qty bigint,
  rev numeric,
  cost numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_session record;
  v_costs boolean := private.can_manage_shop(p_shop_id);
begin
  if p_token is null then
    if not private.can_read_shop(p_shop_id) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
  else
    v_session := private.require_staff_session(p_token);
    if v_session.shop_id <> p_shop_id then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    if not v_costs then
      v_costs := v_session.staff_role = 'owner'
        or (v_session.staff_role = 'manager' and exists (
          select 1 from public.staff s
          where s.id = v_session.staff_id and s.can_view_costs
        ));
    end if;
  end if;

  if p_from is null or p_to is null or p_from > p_to or p_to - p_from > 400 then
    raise exception 'invalid date range' using errcode = '22023';
  end if;

  return query
  select b.business_date, l.name,
         sum(l.qty)::bigint,
         sum(l.qty::numeric * l.price),
         case when v_costs then sum(l.qty::numeric * coalesce(l.cost, 0)) else null end
  from public.bills b
  join public.bill_lines l on l.shop_id = b.shop_id and l.bill_id = b.id
  where b.shop_id = p_shop_id
    and b.business_date between p_from and p_to
    and not b.voided
    and l.type = 'addon'
  group by b.business_date, l.name
  order by 1, 4 desc, 2;
end;
$$;

revoke all on function public.get_addon_sales(uuid, date, date, text) from public, anon;
grant execute on function public.get_addon_sales(uuid, date, date, text) to authenticated;

-- ลบบัญชีธนาคารที่เคยถูกใช้ในบิลไม่ได้ (ฝั่งเซิร์ฟเวอร์เป็นผู้ตัดสิน เพราะแอปโหลดบิลแค่ 7 วัน)
create or replace function private.forbid_bank_account_in_use()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.bills b
    where b.shop_id = old.shop_id and b.bank_account_id = old.id
  ) then
    raise exception 'บัญชีธนาคารนี้มีประวัติรับชำระเงินแล้ว กรุณาปิดใช้งานแทนการลบ'
      using errcode = '23503';
  end if;
  return old;
end;
$$;

create trigger bank_accounts_in_use_guard before delete on public.bank_accounts
  for each row execute function private.forbid_bank_account_in_use();
revoke all on function private.forbid_bank_account_in_use() from public, anon, authenticated;
