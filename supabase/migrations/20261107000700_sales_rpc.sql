-- RPC งานขาย: สูตรคำนวณต้องตรงกับ calcOrder ใน app/lib/domain/order_calc.dart
-- ทุก RPC ระบุผู้ทำจาก session token ไม่เชื่อ staff_id ที่เครื่องส่งมา และส่งซ้ำด้วย id เดิมได้โดยไม่บันทึกซ้ำ

alter table public.devices add column receipt_seq bigint not null default 0 check (receipt_seq >= 0);

drop index public.table_sessions_open_idx;
create unique index table_sessions_one_open_idx on public.table_sessions (shop_id, table_id) where closed_at is null;
create unique index shifts_one_open_idx on public.shifts (shop_id) where closed_at is null;

-- รอบสั่ง/การปรับรายการถูกแก้ไม่ได้ จึงบันทึกแยกว่าเหตุการณ์ไหนถูกคิดเงินไปแล้ว
create table public.settled_table_events (
  event_id uuid primary key,
  shop_id uuid not null,
  bill_id uuid not null,
  foreign key (shop_id, bill_id) references public.bills (shop_id, id) on delete restrict
);
create index settled_table_events_bill_idx on public.settled_table_events (shop_id, bill_id);
alter table public.settled_table_events enable row level security;
grant select on public.settled_table_events to authenticated;
create policy shop_read on public.settled_table_events for select to authenticated
  using ((select private.can_read_shop(shop_id)));
create trigger settled_table_events_append_only before update or delete on public.settled_table_events
  for each row execute function private.forbid_mutation();

create function private.calc_bill_amounts(
  p_subtotal bigint,
  p_service_pct numeric,
  p_vat_mode text,
  p_vat_rate numeric,
  p_rounding text,
  out service bigint,
  out vat bigint,
  out rounding bigint,
  out total bigint
)
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_base bigint;
begin
  service := round(p_subtotal * p_service_pct / 100);
  v_base := p_subtotal + service;
  vat := 0;
  rounding := 0;
  total := v_base;
  if p_vat_mode = 'excluded' and p_vat_rate > 0 then
    vat := round(v_base * p_vat_rate / 100);
    total := v_base + vat;
  end if;
  if p_rounding = 'down' and total % 100 <> 0 then
    rounding := -(total % 100);
    total := total + rounding;
  end if;
  if p_vat_mode = 'included' and p_vat_rate > 0 then
    vat := round(total * p_vat_rate / (100 + p_vat_rate));
  end if;
end;
$$;

create function private.validate_addons(p_shop_id uuid, p_addons jsonb) returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if jsonb_typeof(p_addons) <> 'object' or exists (
    select 1
    from jsonb_each_text(p_addons) e
    left join public.addons a on a.shop_id = p_shop_id and a.id = e.key::uuid
    where a.id is null or e.value::integer <= 0
  ) then
    raise exception 'invalid addon list' using errcode = '22023';
  end if;
end;
$$;

-- ตัดสต็อกแล้วไม่ต่ำกว่า 0 เหมือน takeStock (p_sign = -1 คือคืนสต็อก)
create function private.take_stock(p_shop_id uuid, p_addons jsonb, p_sign integer) returns void
language sql
set search_path = ''
as $$
  update public.addons a
  set stock = greatest(0, a.stock - p_sign * e.value::integer)
  from jsonb_each_text(p_addons) e
  where a.shop_id = p_shop_id and a.id = e.key::uuid;
$$;

-- ล็อกแถวเพื่อกันสองเครื่องคิดเงินรอบเดียวกันพร้อมกัน
create function private.open_or_get_session(
  p_shop_id uuid,
  p_session_id uuid,
  p_table_id uuid,
  p_package_id uuid,
  p_timing text,
  p_notes text,
  p_at timestamptz
) returns public.table_sessions
language plpgsql
set search_path = ''
as $$
declare
  v_session public.table_sessions;
begin
  select * into v_session from public.table_sessions ts
  where ts.id = p_session_id and ts.shop_id = p_shop_id
  for update;

  if v_session.id is not null then
    if v_session.closed_at is not null then
      raise exception 'table session is closed' using errcode = '22023';
    end if;
    return v_session;
  end if;

  if not exists (select 1 from public.packages p where p.id = p_package_id and p.shop_id = p_shop_id) then
    raise exception 'unknown package' using errcode = '22023';
  end if;

  insert into public.table_sessions (id, shop_id, table_id, package_id, opened_at, timing, notes)
  values (p_session_id, p_shop_id, p_table_id, p_package_id, p_at, p_timing, coalesce(p_notes, ''))
  returning * into v_session;
  return v_session;
end;
$$;

-- ยอดที่ยังไม่ถูกคิดเงินของโต๊ะ เหมือน tableTotals
create function private.session_unsettled_totals(
  p_session_id uuid,
  out a integer,
  out c integer,
  out f integer,
  out addons jsonb
)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_adj_a integer;
  v_adj_c integer;
  v_adj_f integer;
begin
  select coalesce(sum(r.heads_a), 0), coalesce(sum(r.heads_c), 0), coalesce(sum(r.heads_f), 0)
  into a, c, f
  from public.table_rounds r
  where r.session_id = p_session_id
    and not exists (select 1 from public.settled_table_events s where s.event_id = r.id);

  select
    coalesce(sum(j.qty) filter (where j.key = 'a'), 0),
    coalesce(sum(j.qty) filter (where j.key = 'c'), 0),
    coalesce(sum(j.qty) filter (where j.key = 'f'), 0)
  into v_adj_a, v_adj_c, v_adj_f
  from public.table_adjustments j
  where j.session_id = p_session_id and j.kind = 'head'
    and not exists (select 1 from public.settled_table_events s where s.event_id = j.id);

  a := greatest(0, a - v_adj_a);
  c := greatest(0, c - v_adj_c);
  f := greatest(0, f - v_adj_f);

  select coalesce(jsonb_object_agg(x.k, x.q) filter (where x.q > 0), '{}') into addons
  from (
    select u.k, sum(u.q) as q
    from (
      select e.key as k, e.value::integer as q
      from public.table_rounds r
      cross join lateral jsonb_each_text(r.addons) e
      where r.session_id = p_session_id
        and not exists (select 1 from public.settled_table_events s where s.event_id = r.id)
      union all
      select j.key, -j.qty
      from public.table_adjustments j
      where j.session_id = p_session_id and j.kind = 'addon'
        and not exists (select 1 from public.settled_table_events s where s.event_id = j.id)
    ) u
    group by u.k
  ) x;
end;
$$;

-- ผลลัพธ์ส่งกลับเครื่อง: ไม่มีคอลัมน์ต้นทุน
create function private.bill_json(p_bill_id uuid) returns jsonb
language sql
stable
set search_path = ''
as $$
  select to_jsonb(b) || jsonb_build_object('lines', (
    select coalesce(jsonb_agg(to_jsonb(l) - 'cost' order by l.line_no), '[]')
    from public.bill_lines l
    where l.shop_id = b.shop_id and l.bill_id = b.id
  ))
  from public.bills b
  where b.id = p_bill_id;
$$;

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
  p_notes text default ''
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

  update public.devices d set receipt_seq = d.receipt_seq + 1
  where d.id = v_me.device_id returning d.receipt_seq into v_seq;
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

-- เหมือน voidBill: แคชเชียร์ยกเลิกได้เฉพาะบิลของโต๊ะที่ยังเปิดอยู่ เจ้าของ/ผู้จัดการได้ทุกบิล
create function public.void_bill(p_token text, p_bill_id uuid, p_reason text, p_at timestamptz) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
  v_bill public.bills;
  v_session public.table_sessions;
  v_returned jsonb;
begin
  v_me := private.require_staff_session(p_token);

  select * into v_bill from public.bills b
  where b.id = p_bill_id and b.shop_id = v_me.shop_id
  for update;
  if v_bill.id is null or v_bill.voided then
    return false;
  end if;

  select * into v_session from public.table_sessions ts
  where ts.id = v_bill.session_id and ts.closed_at is null
  for update;

  if v_me.staff_role = 'cashier' and v_session.id is null then
    raise exception 'cashier can only void bills of an open table' using errcode = '42501';
  end if;

  update public.bills b
  set voided = true,
      void_reason = coalesce(nullif(trim(p_reason), ''), 'ไม่ระบุ'),
      void_by = v_me.staff_name,
      void_at = p_at
  where b.id = p_bill_id;

  select coalesce(jsonb_object_agg(x.item_id, x.qty), '{}') into v_returned
  from (
    select l.item_id, sum(l.qty) as qty
    from public.bill_lines l
    where l.shop_id = v_me.shop_id and l.bill_id = p_bill_id and l.type = 'addon'
    group by l.item_id
  ) x;
  perform private.take_stock(v_me.shop_id, v_returned, -1);

  if v_session.id is not null
    and not exists (
      select 1 from public.bills b
      where b.shop_id = v_me.shop_id and b.session_id = v_session.id and not b.voided
    )
    and not exists (
      select 1 from public.table_rounds r
      where r.session_id = v_session.id
        and not exists (select 1 from public.settled_table_events s where s.event_id = r.id)
    )
  then
    update public.table_sessions ts set closed_at = p_at where ts.id = v_session.id;
  end if;

  return true;
end;
$$;

create function public.send_round(
  p_token text,
  p_round_id uuid,
  p_session_id uuid,
  p_table_id uuid,
  p_package_id uuid,
  p_timing text,
  p_heads_a integer,
  p_heads_c integer,
  p_heads_f integer,
  p_addons jsonb,
  p_at timestamptz,
  p_notes text default ''
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
  v_session public.table_sessions;
begin
  v_me := private.require_staff_session(p_token);

  if exists (select 1 from public.table_rounds r where r.id = p_round_id and r.shop_id = v_me.shop_id) then
    return;
  end if;
  if least(p_heads_a, p_heads_c, p_heads_f) < 0 then
    raise exception 'invalid head count' using errcode = '22023';
  end if;
  perform private.validate_addons(v_me.shop_id, p_addons);

  v_session := private.open_or_get_session(
    v_me.shop_id, p_session_id, p_table_id, p_package_id, p_timing, p_notes, p_at
  );
  insert into public.table_rounds (id, shop_id, session_id, at, staff_id, heads_a, heads_c, heads_f, addons)
  values (p_round_id, v_me.shop_id, v_session.id, p_at, v_me.staff_id, p_heads_a, p_heads_c, p_heads_f, p_addons);
  perform private.take_stock(v_me.shop_id, p_addons, 1);
end;
$$;

-- เหมือน adjustSent: ลดได้ไม่เกินจำนวนที่มี คืน false ถ้าไม่มีอะไรให้ลด
create function public.adjust_sent(
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

-- เก็บโต๊ะ: เหมือน _onTableClosed ที่ไม่ให้เก็บถ้ายังมียอดค้าง
create function public.close_table(p_token text, p_session_id uuid, p_at timestamptz) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
  v_totals record;
begin
  v_me := private.require_staff_session(p_token);

  perform 1 from public.table_sessions ts
  where ts.id = p_session_id and ts.shop_id = v_me.shop_id and ts.closed_at is null
  for update;
  if not found then
    return;
  end if;

  v_totals := private.session_unsettled_totals(p_session_id);
  if v_totals.a + v_totals.c + v_totals.f > 0 or v_totals.addons <> '{}' then
    raise exception 'table still has an unpaid balance' using errcode = '22023';
  end if;

  update public.table_sessions ts set closed_at = p_at where ts.id = p_session_id;
end;
$$;

-- ยกเลิกโต๊ะ: เหมือน cancelOpenTable คืนสต็อกของรอบที่ยังไม่คิดเงินแล้วปิดโต๊ะ
create function public.cancel_table(p_token text, p_session_id uuid, p_at timestamptz) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
  v_totals record;
begin
  v_me := private.require_staff_session(p_token);

  perform 1 from public.table_sessions ts
  where ts.id = p_session_id and ts.shop_id = v_me.shop_id and ts.closed_at is null
  for update;
  if not found then
    return;
  end if;

  v_totals := private.session_unsettled_totals(p_session_id);
  perform private.take_stock(v_me.shop_id, v_totals.addons, -1);
  update public.table_sessions ts set closed_at = p_at where ts.id = p_session_id;
end;
$$;

create function public.open_shift(p_token text, p_shift_id uuid, p_float bigint, p_at timestamptz) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
begin
  v_me := private.require_staff_session(p_token);
  insert into public.shifts (id, shop_id, device_id, staff_id, opened_at, float_amount)
  values (p_shift_id, v_me.shop_id, v_me.device_id, v_me.staff_id, p_at, p_float)
  on conflict (id) do nothing;
end;
$$;

create function public.close_shift(p_token text, p_shift_id uuid, p_counted bigint, p_at timestamptz) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
begin
  v_me := private.require_staff_session(p_token);
  update public.shifts sh
  set closed_at = p_at, counted = p_counted, closed_by = v_me.staff_id::text
  where sh.id = p_shift_id and sh.shop_id = v_me.shop_id and sh.closed_at is null;
end;
$$;

revoke all on function public.settle_bill(text, uuid, uuid, uuid, uuid, text, integer, integer, integer, jsonb, uuid, bigint, bigint, timestamptz, uuid, text) from public, anon;
revoke all on function public.void_bill(text, uuid, text, timestamptz) from public, anon;
revoke all on function public.send_round(text, uuid, uuid, uuid, uuid, text, integer, integer, integer, jsonb, timestamptz, text) from public, anon;
revoke all on function public.adjust_sent(text, uuid, uuid, text, text, integer, text, timestamptz) from public, anon;
revoke all on function public.close_table(text, uuid, timestamptz) from public, anon;
revoke all on function public.cancel_table(text, uuid, timestamptz) from public, anon;
revoke all on function public.open_shift(text, uuid, bigint, timestamptz) from public, anon;
revoke all on function public.close_shift(text, uuid, bigint, timestamptz) from public, anon;

grant execute on function public.settle_bill(text, uuid, uuid, uuid, uuid, text, integer, integer, integer, jsonb, uuid, bigint, bigint, timestamptz, uuid, text) to authenticated;
grant execute on function public.void_bill(text, uuid, text, timestamptz) to authenticated;
grant execute on function public.send_round(text, uuid, uuid, uuid, uuid, text, integer, integer, integer, jsonb, timestamptz, text) to authenticated;
grant execute on function public.adjust_sent(text, uuid, uuid, text, text, integer, text, timestamptz) to authenticated;
grant execute on function public.close_table(text, uuid, timestamptz) to authenticated;
grant execute on function public.cancel_table(text, uuid, timestamptz) to authenticated;
grant execute on function public.open_shift(text, uuid, bigint, timestamptz) to authenticated;
grant execute on function public.close_shift(text, uuid, bigint, timestamptz) to authenticated;
