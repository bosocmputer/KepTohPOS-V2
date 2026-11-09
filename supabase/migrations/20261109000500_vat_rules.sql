-- กฎ VAT: ถ้าปัดเศษเปลี่ยนยอดรวม ให้คิด VAT ใหม่จากยอดหลังปัด (ส่วนปัดคือส่วนลด)
-- สูตรต้องตรงกับ calcOrder ใน app/lib/domain/order_calc.dart
create or replace function private.calc_bill_amounts(
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
  v_has_vat boolean := p_vat_mode in ('included', 'excluded') and p_vat_rate > 0;
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
    if v_has_vat then
      vat := round(total * p_vat_rate / (100 + p_vat_rate));
    end if;
  elsif p_vat_mode = 'included' and p_vat_rate > 0 then
    vat := round(total * p_vat_rate / (100 + p_vat_rate));
  end if;
end;
$$;

-- กิจการที่ไม่ได้จดทะเบียน VAT ต้องไม่มีร้านที่ตั้ง VAT รวมใน/แยกนอก
create function private.check_shop_vat_mode() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.vat_mode <> 'none' and not exists (
    select 1 from public.organizations o where o.id = new.org_id and o.vat_registered
  ) then
    raise exception 'vat_mode must be none when the organization is not VAT registered'
      using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function private.check_shop_vat_mode() from public;
create trigger shops_check_vat_mode before insert or update of vat_mode, org_id on public.shops
  for each row execute function private.check_shop_vat_mode();

create function private.check_org_vat_registered() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not new.vat_registered and exists (
    select 1 from public.shops s where s.org_id = new.id and s.vat_mode <> 'none'
  ) then
    raise exception 'set every shop vat_mode to none before turning off VAT registration'
      using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function private.check_org_vat_registered() from public;
create trigger organizations_check_vat_registered before update of vat_registered on public.organizations
  for each row execute function private.check_org_vat_registered();
