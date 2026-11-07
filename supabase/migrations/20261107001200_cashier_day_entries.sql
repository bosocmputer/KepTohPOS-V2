-- แคชเชียร์เห็นรายการซื้อ/ค่าใช้จ่ายของวันทำการนี้ เพื่อยืนยันว่าบันทึกแล้ว แต่ไม่เห็นยอดเงิน
-- วันทำการคิดแบบเดียวกับ settle_bill (เวลาไทยลบ day_cutoff_minutes)
create function public.get_day_entries(p_token text) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me record;
  v_date date;
begin
  v_me := private.require_staff_session(p_token);

  select ((now() at time zone 'Asia/Bangkok') - make_interval(mins => s.day_cutoff_minutes))::date
  into v_date
  from public.shops s where s.id = v_me.shop_id;

  return jsonb_build_object(
    'business_date', v_date,
    'expenses', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', e.id, 'business_date', e.business_date, 'at', e.at,
        'type_id', e.type_id, 'note', e.note
      ) order by e.at), '[]')
      from public.expenses e
      where e.shop_id = v_me.shop_id and e.business_date = v_date
    ),
    'purchases', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'business_date', p.business_date, 'at', p.at,
        'supplier_id', p.supplier_id, 'note', p.note,
        'lines', (
          select coalesce(jsonb_agg(jsonb_build_object('ingredient_id', l.ingredient_id, 'qty', l.qty)), '[]')
          from public.purchase_lines l
          where l.shop_id = p.shop_id and l.purchase_id = p.id
        )
      ) order by p.at), '[]')
      from public.purchases p
      where p.shop_id = v_me.shop_id and p.business_date = v_date
    )
  );
end;
$$;

revoke all on function public.get_day_entries(text) from public, anon;
grant execute on function public.get_day_entries(text) to authenticated;
