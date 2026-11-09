-- ยอดขายรายวันรวมที่ฝั่งฐานข้อมูล (พอร์ตจากการรวมบิลรายวันใน app/lib/domain/ledger.dart)
-- ใช้ numeric ไม่ปัดเศษ ให้ตรงกับฝั่งแอปที่รวมด้วย double
-- addon_cost เป็น NULL เว้นแต่ผู้เรียกมีสิทธิ์เห็นต้นทุน (กฎเดียวกับ get_manager_data)
create or replace function public.get_daily_sales_totals(
  p_shop_id uuid,
  p_from date,
  p_to date,
  p_token text default null
) returns table (
  business_date date,
  bills int,
  a int,
  c int,
  f int,
  gross numeric,
  net numeric,
  buffet_net numeric,
  addon_net numeric,
  addon_cost numeric
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
  with day_bills as (
    select b.business_date as bd,
           count(*)::int as n,
           sum(b.heads_a)::int as ha,
           sum(b.heads_c)::int as hc,
           sum(b.heads_f)::int as hf,
           sum(b.total)::numeric as g,
           sum(b.total - b.vat)::numeric as nt
    from public.bills b
    where b.shop_id = p_shop_id
      and b.business_date between p_from and p_to
      and not b.voided
    group by b.business_date
  ),
  day_lines as (
    select b.business_date as bd,
           sum(case when l.type = 'addon' then 0 else l.qty * l.price * k.k2 end) as bn,
           sum(case when l.type = 'addon' then l.qty * l.price * k.k2 else 0 end) as an,
           sum(case when l.type = 'addon' then l.qty * coalesce(l.cost, 0) else 0 end) as ac
    from public.bills b
    cross join lateral (
      select case when b.subtotal = 0 then 0::numeric
                  else (b.total - b.vat)::numeric / b.subtotal end as k2
    ) k
    join public.bill_lines l on l.shop_id = b.shop_id and l.bill_id = b.id
    where b.shop_id = p_shop_id
      and b.business_date between p_from and p_to
      and not b.voided
    group by b.business_date
  )
  select d.bd, d.n, d.ha, d.hc, d.hf, d.g, d.nt,
         coalesce(x.bn, 0), coalesce(x.an, 0),
         case when v_costs then coalesce(x.ac, 0) else null end
  from day_bills d
  left join day_lines x on x.bd = d.bd
  order by d.bd;
end;
$$;

revoke all on function public.get_daily_sales_totals(uuid, date, date, text) from public, anon;
grant execute on function public.get_daily_sales_totals(uuid, date, date, text) to authenticated;
