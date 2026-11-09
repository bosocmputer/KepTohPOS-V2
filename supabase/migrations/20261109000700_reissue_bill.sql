-- ออกบิลใหม่แทนบิลเดิม (เปลี่ยนวิธีชำระ/ออกใบกำกับภาษีใหม่) ภายในเดือนภาษีเดียวกัน
alter table public.bills
  add column replaces_bill_id uuid references public.bills (id) on delete restrict;
create unique index bills_replaces_bill_uidx on public.bills (replaces_bill_id) where replaces_bill_id is not null;

create function public.reissue_bill(
  p_shop_id uuid,
  p_bill_id uuid,
  p_new_id uuid,
  p_reason text,
  p_method_id uuid default null,
  p_bank_account_id uuid default null,
  p_token text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor text;
  v_me record;
  v_existing uuid;
  v_shop public.shops;
  v_old public.bills;
  v_today date;
  v_shift_id uuid;
  v_method public.payment_methods;
  v_device_code text;
  v_machine_code text;
  v_seq bigint;
  v_no text;
  v_is_tax boolean;
  v_received bigint;
  v_change bigint;
  v_bank_id uuid;
  v_bank_info text;
  v_now timestamptz := now();
begin
  if private.can_manage_shop(p_shop_id) then
    v_actor := 'เจ้าของ';
  else
    v_me := private.require_staff_session(p_token);
    if v_me.shop_id is distinct from p_shop_id or v_me.staff_role not in ('owner', 'manager') then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    v_actor := v_me.staff_name;
  end if;

  select b.shop_id into v_existing from public.bills b where b.id = p_new_id;
  if v_existing = p_shop_id then
    return private.bill_json(p_new_id);
  elsif v_existing is not null then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  if nullif(trim(p_reason), '') is null then
    raise exception 'reason is required' using errcode = '22023';
  end if;

  select * into v_old from public.bills b where b.id = p_bill_id and b.shop_id = p_shop_id for update;
  if v_old.id is null then
    raise exception 'bill not found' using errcode = '22023';
  end if;
  if v_old.voided then
    raise exception 'bill already voided' using errcode = '22023';
  end if;

  select * into v_shop from public.shops s where s.id = p_shop_id;
  v_today := ((v_now at time zone 'Asia/Bangkok') - make_interval(mins => v_shop.day_cutoff_minutes))::date;
  if date_trunc('month', v_old.business_date) <> date_trunc('month', v_today) then
    raise exception 'reissue only within the same tax month' using errcode = '22023';
  end if;

  select sh.id into v_shift_id from public.shifts sh where sh.shop_id = p_shop_id and sh.closed_at is null;
  if v_shift_id is null then
    raise exception 'no open shift' using errcode = '22023';
  end if;

  if p_method_id is null then
    v_method.id := v_old.method_id;
    v_method.name := v_old.method_name;
    v_method.type := v_old.method_type;
    v_received := v_old.received;
    v_change := v_old.change_amount;
    v_bank_id := v_old.bank_account_id;
    v_bank_info := v_old.bank_account_info;
  else
    select * into v_method from public.payment_methods m
    where m.id = p_method_id and m.shop_id = p_shop_id and m.active;
    if v_method.id is null then
      raise exception 'unknown payment method' using errcode = '22023';
    end if;
    v_received := v_old.total;
    v_change := 0;
    if v_method.type = 'transfer' then
      select b.id, b.bank_name || ' · ' || b.account_no into v_bank_id, v_bank_info
      from public.bank_accounts b
      where b.shop_id = p_shop_id and b.active and b.id = p_bank_account_id;
      if v_bank_id is null then
        raise exception 'unknown bank account' using errcode = '22023';
      end if;
    end if;
  end if;

  -- เลขบิลใหม่ออกจากเครื่องของบิลเดิม
  select d.code, d.rd_machine_code into v_device_code, v_machine_code
  from public.devices d where d.id = v_old.device_id for update;
  update public.devices d set receipt_seq = d.receipt_seq + 1
  where d.id = v_old.device_id returning d.receipt_seq into v_seq;
  v_no := v_shop.branch_code || '-' || v_device_code || '-' || lpad(v_seq::text, 6, '0');

  select o.vat_registered and v_shop.vat_mode <> 'none' and v_machine_code is not null
  into v_is_tax from public.organizations o where o.id = v_shop.org_id;

  -- ยกเลิกบิลเดิม: ไม่คืนสต็อก ไม่แตะโต๊ะ
  update public.bills b
  set voided = true,
      void_reason = 'ออกใบใหม่แทน: ' || trim(p_reason),
      void_by = v_actor,
      void_at = v_now
  where b.id = p_bill_id;

  insert into public.bills (
    id, shop_id, device_id, shift_id, session_id, no, business_date, at,
    table_id, table_name, staff_id, staff_name, package_id,
    subtotal, service, vat, rounding, total, heads_a, heads_c, heads_f,
    method_id, method_name, method_type, received, change_amount,
    vat_mode, vat_rate, bank_account_id, bank_account_info, eat_until, time_limit_min,
    rd_machine_code, is_tax_invoice, replaces_bill_id
  ) values (
    p_new_id, p_shop_id, v_old.device_id, v_shift_id, v_old.session_id, v_no, v_today, v_now,
    v_old.table_id, v_old.table_name, v_old.staff_id, v_old.staff_name, v_old.package_id,
    v_old.subtotal, v_old.service, v_old.vat, v_old.rounding, v_old.total, v_old.heads_a, v_old.heads_c, v_old.heads_f,
    v_method.id, v_method.name, v_method.type, v_received, v_change,
    v_old.vat_mode, v_old.vat_rate, v_bank_id, v_bank_info, v_old.eat_until, v_old.time_limit_min,
    v_machine_code, coalesce(v_is_tax, false), p_bill_id
  );

  insert into public.bill_lines (shop_id, bill_id, line_no, type, item_id, name, qty, price, cost)
  select l.shop_id, p_new_id, l.line_no, l.type, l.item_id, l.name, l.qty, l.price, l.cost
  from public.bill_lines l where l.shop_id = p_shop_id and l.bill_id = p_bill_id;

  return private.bill_json(p_new_id);
end;
$$;

revoke all on function public.reissue_bill(uuid, uuid, uuid, text, uuid, uuid, text) from public, anon;
grant execute on function public.reissue_bill(uuid, uuid, uuid, text, uuid, uuid, text) to authenticated;
