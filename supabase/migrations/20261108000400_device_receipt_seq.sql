-- เลขใบเสร็จออกจากเครื่องได้ เพื่อขายตอนเน็ตหลุดแล้วส่งตามทีหลังโดยเลขไม่เปลี่ยน (M2)
-- เพิ่มพารามิเตอร์ p_seq ทำให้ signature เปลี่ยน จึงต้องลบฟังก์ชันเดิมก่อน (ไม่แตะข้อมูลในตาราง)
drop function public.settle_bill(text, uuid, uuid, uuid, uuid, text, integer, integer, integer, jsonb, uuid, bigint, bigint, timestamptz, uuid, text);

create function public.settle_bill(
  p_token text,
  p_bill_id uuid,
  p_session_id uuid,
  p_table_id uuid,
  p_package_id uuid,
  p_timing text,
  p_heads_a integer,
  p_heads_c integer,
  p_heads_f integer,
  p_addons jsonb,
  p_method_id uuid,
  p_received bigint,
  p_expected_total bigint,
  p_at timestamptz,
  p_bank_account_id uuid default null,
  p_notes text default '',
  p_seq bigint default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
  v_bill_shop uuid;
  v_shop public.shops;
  v_session public.table_sessions;
  v_pkg public.packages;
  v_method public.payment_methods;
  v_table_name text;
  v_a integer := p_heads_a;
  v_c integer := p_heads_c;
  v_f integer := p_heads_f;
  v_addons jsonb := p_addons;
  v_totals record;
  v_subtotal bigint;
  v_amounts record;
  v_received bigint;
  v_change bigint := 0;
  v_bank_id uuid;
  v_bank_info text;
  v_eat_until timestamptz;
  v_limit integer := 0;
  v_seq bigint;
  v_no text;
  v_device_code text;
  v_shift_id uuid;
begin
  v_me := private.require_staff_session(p_token);

  select d.code into v_device_code from public.devices d where d.id = v_me.device_id for update;

  select b.shop_id into v_bill_shop from public.bills b where b.id = p_bill_id;
  if v_bill_shop = v_me.shop_id then
    return private.bill_json(p_bill_id);
  elsif v_bill_shop is not null then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  if least(p_heads_a, p_heads_c, p_heads_f) < 0 then
    raise exception 'invalid head count' using errcode = '22023';
  end if;
  perform private.validate_addons(v_me.shop_id, p_addons);

  -- เหมือน canConfirmPayment: ต้องมีกะเปิดอยู่ ยอดจึงจะเข้าสรุปกะ
  select sh.id into v_shift_id from public.shifts sh where sh.shop_id = v_me.shop_id and sh.closed_at is null;
  if v_shift_id is null then
    raise exception 'no open shift' using errcode = '22023';
  end if;

  select * into v_shop from public.shops s where s.id = v_me.shop_id;
  v_session := private.open_or_get_session(
    v_me.shop_id, p_session_id, p_table_id, p_package_id, p_timing, p_notes, p_at
  );
  select * into v_pkg from public.packages p where p.id = v_session.package_id and p.shop_id = v_me.shop_id;

  if v_session.timing = 'after' then
    if p_heads_a + p_heads_c + p_heads_f > 0 or p_addons <> '{}' then
      insert into public.table_rounds (id, shop_id, session_id, at, staff_id, heads_a, heads_c, heads_f, addons)
      values (gen_random_uuid(), v_me.shop_id, v_session.id, p_at, v_me.staff_id, p_heads_a, p_heads_c, p_heads_f, p_addons);
      perform private.take_stock(v_me.shop_id, p_addons, 1);
    end if;
    v_totals := private.session_unsettled_totals(v_session.id);
    v_a := v_totals.a;
    v_c := v_totals.c;
    v_f := v_totals.f;
    v_addons := v_totals.addons;
  else
    perform private.take_stock(v_me.shop_id, p_addons, 1);
  end if;

  if v_a + v_c + v_f = 0 and v_addons = '{}' then
    raise exception 'order is empty' using errcode = '22023';
  end if;

  select v_a * v_pkg.adult_price + v_c * v_pkg.child_price + coalesce(sum(a.price * e.value::integer), 0)
  into v_subtotal
  from jsonb_each_text(v_addons) e
  join public.addons a on a.shop_id = v_me.shop_id and a.id = e.key::uuid;

  v_amounts := private.calc_bill_amounts(
    v_subtotal, v_shop.service_pct, v_shop.vat_mode, v_shop.vat_rate, v_shop.rounding
  );
  if v_amounts.total <> p_expected_total then
    raise exception 'total mismatch: expected %, server calculated %', p_expected_total, v_amounts.total
      using errcode = 'P0001';
  end if;

  select * into v_method from public.payment_methods m where m.id = p_method_id and m.shop_id = v_me.shop_id;
  if v_method.id is null then
    raise exception 'unknown payment method' using errcode = '22023';
  end if;

  v_received := v_amounts.total;
  if v_method.type = 'cash' then
    v_received := p_received;
    v_change := p_received - v_amounts.total;
    if v_change < 0 then
      raise exception 'received amount is less than total' using errcode = '22023';
    end if;
  elsif v_method.type = 'transfer' then
    select b.id, b.bank_name || ' · ' || b.account_no into v_bank_id, v_bank_info
    from public.bank_accounts b
    where b.shop_id = v_me.shop_id and b.active and (p_bank_account_id is null or b.id = p_bank_account_id)
    order by b.bank_name, b.account_no
    limit 1;
  end if;

  if v_shop.use_timer and v_pkg.time_limit_min > 0 then
    v_limit := v_pkg.time_limit_min;
    v_eat_until := v_session.opened_at + make_interval(mins => v_limit);
  end if;

  -- เครื่องออกเลขเองได้ (ขายตอนออฟไลน์): ต้องมากกว่าเลขล่าสุดของเครื่อง ห้ามซ้ำหรือย้อนหลัง
  if p_seq is null then
    update public.devices d set receipt_seq = d.receipt_seq + 1
    where d.id = v_me.device_id returning d.receipt_seq into v_seq;
  else
    update public.devices d set receipt_seq = p_seq
    where d.id = v_me.device_id and d.receipt_seq < p_seq
    returning d.receipt_seq into v_seq;
    if v_seq is null then
      raise exception 'receipt number already used' using errcode = '23505';
    end if;
  end if;
  v_no := v_shop.branch_code || '-' || v_device_code || '-' || lpad(v_seq::text, 6, '0');

  select t.name into v_table_name from public.dining_tables t where t.id = v_session.table_id;

  insert into public.bills (
    id, shop_id, device_id, shift_id, session_id, no, business_date, at,
    table_id, table_name, staff_id, staff_name, package_id,
    subtotal, service, vat, rounding, total, heads_a, heads_c, heads_f,
    method_id, method_name, method_type, received, change_amount,
    vat_mode, vat_rate, bank_account_id, bank_account_info, eat_until, time_limit_min
  ) values (
    p_bill_id, v_me.shop_id, v_me.device_id, v_shift_id, v_session.id, v_no,
    ((p_at at time zone 'Asia/Bangkok') - make_interval(mins => v_shop.day_cutoff_minutes))::date, p_at,
    v_session.table_id, coalesce(v_table_name, '-'), v_me.staff_id, v_me.staff_name, v_session.package_id,
    v_subtotal, v_amounts.service, v_amounts.vat, v_amounts.rounding, v_amounts.total, v_a, v_c, v_f,
    v_method.id, v_method.name, v_method.type, v_received, v_change,
    v_shop.vat_mode, v_shop.vat_rate, v_bank_id, v_bank_info, v_eat_until, v_limit
  );

  insert into public.bill_lines (shop_id, bill_id, line_no, type, item_id, name, qty, price, cost)
  select v_me.shop_id, p_bill_id, row_number() over (order by l.sort_key, l.name), l.type, l.item_id, l.name, l.qty, l.price, l.cost
  from (
    select 1 as sort_key, 'buffet' as type, null::text as item_id, v_pkg.name || ' · ผู้ใหญ่' as name, v_a as qty, v_pkg.adult_price as price, null::bigint as cost
    where v_a > 0
    union all
    select 2, 'buffet', null, v_pkg.name || ' · เด็ก', v_c, v_pkg.child_price, null
    where v_c > 0
    union all
    select 3, 'buffet', null, 'เด็กเล็ก (ทานฟรี)', v_f, 0, null
    where v_f > 0
    union all
    select 4, 'addon', a.id::text, a.name, e.value::integer, a.price, a.cost
    from jsonb_each_text(v_addons) e
    join public.addons a on a.shop_id = v_me.shop_id and a.id = e.key::uuid
  ) l;

  if v_session.timing = 'after' then
    insert into public.settled_table_events (event_id, shop_id, bill_id)
    select r.id, v_me.shop_id, p_bill_id from public.table_rounds r
    where r.session_id = v_session.id
      and not exists (select 1 from public.settled_table_events s where s.event_id = r.id)
    union all
    select j.id, v_me.shop_id, p_bill_id from public.table_adjustments j
    where j.session_id = v_session.id
      and not exists (select 1 from public.settled_table_events s where s.event_id = j.id);
  end if;

  return private.bill_json(p_bill_id);
end;
$$;

revoke all on function public.settle_bill(text, uuid, uuid, uuid, uuid, text, integer, integer, integer, jsonb, uuid, bigint, bigint, timestamptz, uuid, text, bigint) from public, anon;
grant execute on function public.settle_bill(text, uuid, uuid, uuid, uuid, text, integer, integer, integer, jsonb, uuid, bigint, bigint, timestamptz, uuid, text, bigint) to authenticated;
