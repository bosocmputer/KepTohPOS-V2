-- รายงานภาษีขายรายเดือน + สรุปรายวันรายเครื่อง (ประกาศอธิบดีฯ POS ฉบับ 46 ข้อ 5(8)(9))
-- เฉพาะเจ้าของ/ผู้จัดการ (กฎเดียวกับ reissue_bill) และไม่คืนคอลัมน์ต้นทุน
create function public.get_sales_tax_report(
  p_shop_id uuid,
  p_month date,
  p_token text default null
) returns table (
  business_date date,
  at timestamptz,
  no text,
  doc_type text,
  device_code text,
  rd_machine_code text,
  buyer_name text,
  buyer_tax_id text,
  buyer_branch text,
  base bigint,
  vat bigint,
  total bigint,
  voided boolean,
  void_reason text,
  replaces_no text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_me record;
  v_from date;
begin
  if not private.can_manage_shop(p_shop_id) then
    v_me := private.require_staff_session(p_token);
    if v_me.shop_id is distinct from p_shop_id or v_me.staff_role not in ('owner', 'manager') then
      raise exception 'not allowed' using errcode = '42501';
    end if;
  end if;

  if p_month is null then
    raise exception 'invalid month' using errcode = '22023';
  end if;
  v_from := date_trunc('month', p_month)::date;

  return query
  select b.business_date, b.at, b.no,
         case when b.is_full_invoice then 'full' when b.is_tax_invoice then 'abb' else 'receipt' end,
         d.code, b.rd_machine_code, b.buyer_name, b.buyer_tax_id, b.buyer_branch,
         b.total - b.vat, b.vat, b.total, b.voided, b.void_reason, r.no
  from public.bills b
  join public.devices d on d.id = b.device_id
  left join public.bills r on r.id = b.replaces_bill_id
  where b.shop_id = p_shop_id
    and b.business_date >= v_from
    and b.business_date < (v_from + interval '1 month')::date
  order by b.business_date, b.at, b.no;
end;
$$;

revoke all on function public.get_sales_tax_report(uuid, date, text) from public, anon;
grant execute on function public.get_sales_tax_report(uuid, date, text) to authenticated;

create function public.get_daily_device_summary(
  p_shop_id uuid,
  p_from date,
  p_to date,
  p_token text default null
) returns table (
  business_date date,
  device_code text,
  rd_machine_code text,
  first_no text,
  last_no text,
  bills int,
  voided int,
  base bigint,
  vat bigint,
  total bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_me record;
begin
  if not private.can_manage_shop(p_shop_id) then
    v_me := private.require_staff_session(p_token);
    if v_me.shop_id is distinct from p_shop_id or v_me.staff_role not in ('owner', 'manager') then
      raise exception 'not allowed' using errcode = '42501';
    end if;
  end if;

  if p_from is null or p_to is null or p_from > p_to or p_to - p_from > 400 then
    raise exception 'invalid date range' using errcode = '22023';
  end if;

  -- ใบกำกับเต็มรูปแยกเป็นแถว 'FULL' ของแต่ละวัน; เลขแรก/สุดท้ายนับทุกใบ (รวมที่ยกเลิก) เรียงตามเวลาออก
  return query
  select b.business_date,
         case when b.is_full_invoice then 'FULL' else d.code end,
         max(b.rd_machine_code),
         (array_agg(b.no order by b.at, b.no))[1],
         (array_agg(b.no order by b.at desc, b.no desc))[1],
         (count(*) filter (where not b.voided))::int,
         (count(*) filter (where b.voided))::int,
         coalesce(sum(b.total - b.vat) filter (where not b.voided), 0)::bigint,
         coalesce(sum(b.vat) filter (where not b.voided), 0)::bigint,
         coalesce(sum(b.total) filter (where not b.voided), 0)::bigint
  from public.bills b
  join public.devices d on d.id = b.device_id
  where b.shop_id = p_shop_id
    and b.business_date between p_from and p_to
  group by b.business_date, case when b.is_full_invoice then 'FULL' else d.code end
  order by 1, 2;
end;
$$;

revoke all on function public.get_daily_device_summary(uuid, date, date, text) from public, anon;
grant execute on function public.get_daily_device_summary(uuid, date, date, text) to authenticated;
