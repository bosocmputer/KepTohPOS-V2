-- ใบกำกับภาษีเต็มรูป (ม.86/4): ออกแทนบิลเดิมในเดือนภาษีเดียวกัน เลขชุดแยก {สาขา}-F-{seq}
alter table public.bills
  add column is_full_invoice boolean not null default false,
  add column buyer_name text,
  add column buyer_tax_id text check (buyer_tax_id ~ '^[0-9]{13}$'),
  add column buyer_branch text check (buyer_branch ~ '^[0-9]{5}$'),
  add column buyer_address text;
alter table public.shops add column full_invoice_seq bigint not null default 0;

create function public.issue_full_invoice(
  p_shop_id uuid,
  p_bill_id uuid,
  p_new_id uuid,
  p_buyer_name text,
  p_buyer_address text,
  p_buyer_tax_id text default null,
  p_buyer_branch text default null,
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
  v_vat_registered boolean;
  v_machine_code text;
  v_no text;
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

  if nullif(trim(p_buyer_name), '') is null or nullif(trim(p_buyer_address), '') is null then
    raise exception 'buyer name and address are required' using errcode = '22023';
  end if;
  if nullif(trim(p_buyer_tax_id), '') is not null then
    if trim(p_buyer_tax_id) !~ '^[0-9]{13}$' then
      raise exception 'buyer tax id must be 13 digits' using errcode = '22023';
    end if;
    if coalesce(trim(p_buyer_branch), '') !~ '^[0-9]{5}$' then
      raise exception 'buyer branch must be 5 digits' using errcode = '22023';
    end if;
  end if;

  select * into v_old from public.bills b where b.id = p_bill_id and b.shop_id = p_shop_id for update;
  if v_old.id is null then
    raise exception 'bill not found' using errcode = '22023';
  end if;
  if v_old.voided then
    raise exception 'bill already voided' using errcode = '22023';
  end if;
  if v_old.is_full_invoice then
    raise exception 'bill is already a full tax invoice' using errcode = '22023';
  end if;

  select * into v_shop from public.shops s where s.id = p_shop_id for update;
  select o.vat_registered into v_vat_registered from public.organizations o where o.id = v_shop.org_id;
  if not v_vat_registered or v_shop.vat_mode = 'none' then
    raise exception 'full tax invoice needs a VAT shop' using errcode = '22023';
  end if;

  v_today := ((v_now at time zone 'Asia/Bangkok') - make_interval(mins => v_shop.day_cutoff_minutes))::date;
  if date_trunc('month', v_old.business_date) <> date_trunc('month', v_today) then
    raise exception 'full tax invoice only within the same tax month' using errcode = '22023';
  end if;

  select sh.id into v_shift_id from public.shifts sh where sh.shop_id = p_shop_id and sh.closed_at is null;
  if v_shift_id is null then
    raise exception 'no open shift' using errcode = '22023';
  end if;

  -- เลขชุดใบกำกับเต็มรูปแยกจากเลขใบเสร็จของเครื่อง (shops ถูกล็อกแถวไว้แล้ว)
  update public.shops s set full_invoice_seq = s.full_invoice_seq + 1
  where s.id = p_shop_id
  returning v_shop.branch_code || '-F-' || lpad(s.full_invoice_seq::text, 6, '0') into v_no;

  v_machine_code := v_old.rd_machine_code;

  update public.bills b
  set voided = true,
      void_reason = 'ออกใบกำกับภาษีเต็มรูปแทน',
      void_by = v_actor,
      void_at = v_now
  where b.id = p_bill_id;

  insert into public.bills (
    id, shop_id, device_id, shift_id, session_id, no, business_date, at,
    table_id, table_name, staff_id, staff_name, package_id,
    subtotal, service, vat, rounding, total, heads_a, heads_c, heads_f,
    method_id, method_name, method_type, received, change_amount,
    vat_mode, vat_rate, bank_account_id, bank_account_info, eat_until, time_limit_min,
    rd_machine_code, is_tax_invoice, replaces_bill_id,
    is_full_invoice, buyer_name, buyer_tax_id, buyer_branch, buyer_address
  ) values (
    p_new_id, p_shop_id, v_old.device_id, v_shift_id, v_old.session_id, v_no, v_today, v_now,
    v_old.table_id, v_old.table_name, v_old.staff_id, v_old.staff_name, v_old.package_id,
    v_old.subtotal, v_old.service, v_old.vat, v_old.rounding, v_old.total, v_old.heads_a, v_old.heads_c, v_old.heads_f,
    v_old.method_id, v_old.method_name, v_old.method_type, v_old.received, v_old.change_amount,
    v_old.vat_mode, v_old.vat_rate, v_old.bank_account_id, v_old.bank_account_info, v_old.eat_until, v_old.time_limit_min,
    v_machine_code, true, p_bill_id,
    true, trim(p_buyer_name), nullif(trim(p_buyer_tax_id), ''),
    case when nullif(trim(p_buyer_tax_id), '') is null then null else trim(p_buyer_branch) end,
    trim(p_buyer_address)
  );

  insert into public.bill_lines (shop_id, bill_id, line_no, type, item_id, name, qty, price, cost)
  select l.shop_id, p_new_id, l.line_no, l.type, l.item_id, l.name, l.qty, l.price, l.cost
  from public.bill_lines l where l.shop_id = p_shop_id and l.bill_id = p_bill_id;

  return private.bill_json(p_new_id);
end;
$$;

revoke all on function public.issue_full_invoice(uuid, uuid, uuid, text, text, text, text, text) from public, anon;
grant execute on function public.issue_full_invoice(uuid, uuid, uuid, text, text, text, text, text) to authenticated;

-- ใบกำกับเต็มรูปห้ามถูกแทนด้วยบิลที่ไม่ใช่ใบเต็มรูป (กัน reissue_bill และทางอื่นที่ insert บิลแทน)
create or replace function private.forbid_full_invoice_downgrade()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.replaces_bill_id is not null and not new.is_full_invoice and exists (
    select 1 from public.bills b where b.id = new.replaces_bill_id and b.is_full_invoice
  ) then
    raise exception 'full tax invoice cannot be reissued' using errcode = '22023';
  end if;
  return new;
end;
$$;

revoke all on function private.forbid_full_invoice_downgrade() from public;

create trigger bills_forbid_full_invoice_downgrade
  before insert on public.bills
  for each row execute function private.forbid_full_invoice_downgrade();
