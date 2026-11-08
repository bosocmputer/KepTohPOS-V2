-- เจ้าของเลือกได้ว่าผู้จัดการแต่ละคนเห็นต้นทุนและกำไรหรือไม่ (ค่าเริ่มต้นไม่เห็น)
-- เจ้าของร้านเห็นเสมอ แคชเชียร์ไม่เห็นเสมอ
alter table public.staff add column can_view_costs boolean not null default false;

create or replace function public.get_manager_data(
  p_shop_id uuid,
  p_from date,
  p_to date,
  p_token text default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_session record;
begin
  if not private.can_manage_shop(p_shop_id) then
    if p_token is null then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    v_session := private.require_staff_session(p_token);
    if v_session.shop_id <> p_shop_id or not (
      v_session.staff_role = 'owner'
      or (v_session.staff_role = 'manager' and exists (
        select 1 from public.staff s
        where s.id = v_session.staff_id and s.can_view_costs
      ))
    ) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
  end if;

  return jsonb_build_object(
    'addon_costs', (
      select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'cost', a.cost)), '[]')
      from public.addons a where a.shop_id = p_shop_id
    ),
    'ingredient_costs', (
      select coalesce(jsonb_agg(jsonb_build_object('id', i.id, 'last_cost', i.last_cost)), '[]')
      from public.ingredients i where i.shop_id = p_shop_id
    ),
    'fixed_costs', (
      select coalesce(jsonb_agg(to_jsonb(f)), '[]') from public.fixed_costs f where f.shop_id = p_shop_id
    ),
    'initial_stock', (
      select coalesce(jsonb_agg(to_jsonb(s)), '[]') from public.initial_stock s where s.shop_id = p_shop_id
    ),
    'expenses', (
      select coalesce(jsonb_agg(to_jsonb(e)), '[]') from public.expenses e
      where e.shop_id = p_shop_id and e.business_date between p_from and p_to
    ),
    'purchases', (
      select coalesce(jsonb_agg(
        to_jsonb(p) || jsonb_build_object('lines', (
          select coalesce(jsonb_agg(to_jsonb(l)), '[]') from public.purchase_lines l
          where l.shop_id = p.shop_id and l.purchase_id = p.id
        ))
      ), '[]')
      from public.purchases p
      where p.shop_id = p_shop_id and p.business_date between p_from and p_to
    ),
    'bill_line_costs', (
      select coalesce(jsonb_agg(jsonb_build_object('bill_id', l.bill_id, 'line_no', l.line_no, 'cost', l.cost)), '[]')
      from public.bill_lines l
      join public.bills b on b.shop_id = l.shop_id and b.id = l.bill_id
      where b.shop_id = p_shop_id and b.business_date between p_from and p_to and l.cost is not null
    )
  );
end;
$$;
