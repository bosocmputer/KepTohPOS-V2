-- เหมือน _onSentItemAdjusted ในแอป: แคชเชียร์ลดรายการที่ส่งแล้วไม่ได้
-- ตรวจซ้ำกับ id เดิมก่อน เพื่อให้การส่งซ้ำของรายการที่สำเร็จแล้วยังคืนผลเดิม
create or replace function public.adjust_sent(
  p_token text,
  p_adjustment_id uuid,
  p_session_id uuid,
  p_kind text,
  p_key text,
  p_qty integer,
  p_reason text,
  p_at timestamptz
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
  v_totals record;
  v_have integer;
  v_n integer;
begin
  v_me := private.require_staff_session(p_token);

  if exists (select 1 from public.table_adjustments j where j.id = p_adjustment_id and j.shop_id = v_me.shop_id) then
    return true;
  end if;
  if v_me.staff_role = 'cashier' then
    raise exception 'cashier cannot adjust sent items' using errcode = '42501';
  end if;
  if p_kind not in ('head', 'addon') or (p_kind = 'head' and p_key not in ('a', 'c', 'f')) then
    raise exception 'invalid adjustment' using errcode = '22023';
  end if;

  perform 1 from public.table_sessions ts
  where ts.id = p_session_id and ts.shop_id = v_me.shop_id and ts.closed_at is null
  for update;
  if not found then
    raise exception 'table session is not open' using errcode = '22023';
  end if;

  v_totals := private.session_unsettled_totals(p_session_id);
  v_have := case p_key
    when 'a' then v_totals.a
    when 'c' then v_totals.c
    when 'f' then v_totals.f
    else coalesce((v_totals.addons ->> p_key)::integer, 0)
  end;
  v_n := least(p_qty, v_have);
  if v_n <= 0 then
    return false;
  end if;

  insert into public.table_adjustments (id, shop_id, session_id, at, by_staff_id, by_name, reason, kind, key, qty)
  values (p_adjustment_id, v_me.shop_id, p_session_id, p_at, v_me.staff_id, v_me.staff_name, coalesce(p_reason, ''), p_kind, p_key, v_n);

  if p_kind = 'addon' then
    perform private.take_stock(v_me.shop_id, jsonb_build_object(p_key, v_n), -1);
  end if;
  return true;
end;
$$;
