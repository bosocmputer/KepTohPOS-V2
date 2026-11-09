-- สองเครื่องเปิดโต๊ะเดียวกัน (เช่นออฟไลน์ทั้งคู่) ด้วย session id ต่างกัน: รวมเข้ารอบที่เปิดอยู่แล้วแทนที่จะ error
create table public.table_session_aliases (
  alias_id uuid primary key,
  session_id uuid not null,
  shop_id uuid not null references public.shops (id) on delete restrict,
  created_at timestamptz not null default now(),
  foreign key (shop_id, session_id) references public.table_sessions (shop_id, id) on delete restrict
);
create index table_session_aliases_session_idx on public.table_session_aliases (shop_id, session_id);

alter table public.table_session_aliases enable row level security;
grant select on public.table_session_aliases to authenticated;
create policy shop_read on public.table_session_aliases
  for select to authenticated using ((select private.can_read_shop(shop_id)));

create or replace function private.open_or_get_session(
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
  v_try integer;
begin
  for v_try in 1..2 loop
    -- id ที่เป็น alias ชี้ไปยังรอบที่รวมไว้แล้ว
    select * into v_session from public.table_sessions ts
    where ts.shop_id = p_shop_id
      and ts.id = coalesce(
        (select a.session_id from public.table_session_aliases a where a.alias_id = p_session_id and a.shop_id = p_shop_id),
        p_session_id)
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

    -- โต๊ะนี้มีรอบเปิดอยู่แล้ว: รวมเข้ารอบนั้น เก็บแพ็กเกจ/เวลาเดิมไว้
    select * into v_session from public.table_sessions ts
    where ts.shop_id = p_shop_id and ts.table_id = p_table_id and ts.closed_at is null
    for update;

    if v_session.id is not null then
      insert into public.table_session_aliases (alias_id, session_id, shop_id)
      values (p_session_id, v_session.id, p_shop_id)
      on conflict (alias_id) do nothing;
      return v_session;
    end if;

    begin
      insert into public.table_sessions (id, shop_id, table_id, package_id, opened_at, timing, notes)
      values (p_session_id, p_shop_id, p_table_id, p_package_id, p_at, p_timing, coalesce(p_notes, ''))
      returning * into v_session;
      return v_session;
    exception when unique_violation then
      -- อีกเครื่องเปิดโต๊ะพร้อมกัน: วนค้นหาใหม่อีกครั้งเดียว
      if v_try = 2 then
        raise;
      end if;
    end;
  end loop;
end;
$$;

-- คำสั่งที่ค้างในคิวด้วย alias id ต้องลงรอบที่รวมแล้ว: แปลง id ผ่าน alias ของร้านก่อนค้นหา
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
  v_sid uuid;
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

  v_sid := coalesce(
    (select a.session_id from public.table_session_aliases a where a.alias_id = p_session_id and a.shop_id = v_me.shop_id),
    p_session_id);
  perform 1 from public.table_sessions ts
  where ts.id = v_sid and ts.shop_id = v_me.shop_id and ts.closed_at is null
  for update;
  if not found then
    raise exception 'table session is not open' using errcode = '22023';
  end if;

  v_totals := private.session_unsettled_totals(v_sid);
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
  values (p_adjustment_id, v_me.shop_id, v_sid, p_at, v_me.staff_id, v_me.staff_name, coalesce(p_reason, ''), p_kind, p_key, v_n);

  if p_kind = 'addon' then
    perform private.take_stock(v_me.shop_id, jsonb_build_object(p_key, v_n), -1);
  end if;
  return true;
end;
$$;

create or replace function public.close_table(p_token text, p_session_id uuid, p_at timestamptz) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
  v_totals record;
  v_sid uuid;
begin
  v_me := private.require_staff_session(p_token);

  v_sid := coalesce(
    (select a.session_id from public.table_session_aliases a where a.alias_id = p_session_id and a.shop_id = v_me.shop_id),
    p_session_id);
  perform 1 from public.table_sessions ts
  where ts.id = v_sid and ts.shop_id = v_me.shop_id and ts.closed_at is null
  for update;
  if not found then
    return;
  end if;

  v_totals := private.session_unsettled_totals(v_sid);
  if v_totals.a + v_totals.c + v_totals.f > 0 or v_totals.addons <> '{}' then
    raise exception 'table still has an unpaid balance' using errcode = '22023';
  end if;

  update public.table_sessions ts set closed_at = p_at where ts.id = v_sid;
end;
$$;

create or replace function public.set_table_notes(p_token text, p_session_id uuid, p_notes text) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
begin
  v_me := private.require_staff_session(p_token);
  update public.table_sessions ts
  set notes = coalesce(trim(p_notes), '')
  where ts.shop_id = v_me.shop_id and ts.closed_at is null
    and ts.id = coalesce(
      (select a.session_id from public.table_session_aliases a where a.alias_id = p_session_id and a.shop_id = v_me.shop_id),
      p_session_id);
  return found;
end;
$$;

-- ยกเลิกโต๊ะด้วย alias id: ปฏิเสธ เพราะเครื่องนั้นยังไม่เห็นรายการของอีกเครื่องที่รวมเข้ามา
-- (กันรายการของอีกเครื่องหายเงียบ ๆ) ให้ดึงข้อมูลใหม่แล้วยกเลิกจากหน้าโต๊ะอีกครั้ง
create or replace function public.cancel_table(p_token text, p_session_id uuid, p_at timestamptz) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me record;
  v_totals record;
begin
  v_me := private.require_staff_session(p_token);

  if exists (
    select 1 from public.table_session_aliases a
    where a.alias_id = p_session_id and a.shop_id = v_me.shop_id
  ) then
    raise exception 'table session was merged; reload before cancelling' using errcode = '22023';
  end if;

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
