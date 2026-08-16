-- Android gate operations. Additive only: do not delete existing data.

create table if not exists public.gate_ledger_mains (
  id uuid primary key default gen_random_uuid(),
  branch_id text not null references public.branches(id),
  driver_id uuid not null references public.drivers(id),
  ledger_date date not null,
  status text not null default 'draft' check (status in ('draft', 'settled')),
  created_by uuid not null references auth.users(id),
  settled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.gate_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  ledger_id uuid not null references public.gate_ledger_mains(id),
  parcel_id uuid not null references public.parcels(id),
  tracking_id_snapshot text not null,
  destination_town_snapshot text not null,
  attached_at timestamptz not null default now(),
  attached_by uuid not null references auth.users(id),
  removed_at timestamptz,
  removed_by uuid references auth.users(id)
);

create unique index if not exists gate_ledger_entries_active_parcel_unique
  on public.gate_ledger_entries(parcel_id)
  where removed_at is null;

create index if not exists gate_ledger_mains_branch_date_idx
  on public.gate_ledger_mains(branch_id, ledger_date desc);

create index if not exists gate_ledger_entries_ledger_idx
  on public.gate_ledger_entries(ledger_id, attached_at)
  where removed_at is null;

create table if not exists public.gate_incoming_mains (
  id uuid primary key default gen_random_uuid(),
  branch_id text not null references public.branches(id),
  driver_id uuid not null references public.drivers(id),
  incoming_date date not null,
  driver_payment_status text not null default 'unpaid'
    check (driver_payment_status in ('unpaid', 'paid')),
  driver_payment_amount numeric(12, 2) not null default 0
    check (driver_payment_amount >= 0),
  driver_paid_at timestamptz,
  driver_paid_by uuid references auth.users(id),
  driver_payment_note text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.gate_incoming_entries (
  id uuid primary key default gen_random_uuid(),
  incoming_id uuid not null references public.gate_incoming_mains(id),
  parcel_id uuid references public.parcels(id),
  tracking_id text,
  entry_type text not null check (entry_type in ('existing_parcel', 'manual')),
  receiver_name text not null,
  receiver_phone text not null,
  destination_town text not null,
  payment_status text not null check (payment_status in ('paid', 'unpaid')),
  total_charges numeric(12, 2) not null default 0 check (total_charges >= 0),
  cash_advance numeric(12, 2) not null default 0 check (cash_advance >= 0),
  note text,
  claimed boolean not null default false,
  claimed_at timestamptz,
  claimed_by uuid references auth.users(id),
  claim_note text,
  attached_at timestamptz not null default now(),
  attached_by uuid not null references auth.users(id),
  removed_at timestamptz,
  removed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint gate_incoming_entries_source_check check (
    (entry_type = 'existing_parcel' and parcel_id is not null and tracking_id is not null)
    or (entry_type = 'manual' and parcel_id is null and tracking_id is null)
  )
);

create unique index if not exists gate_incoming_entries_active_parcel_unique
  on public.gate_incoming_entries(parcel_id)
  where parcel_id is not null and removed_at is null;

create index if not exists gate_incoming_mains_branch_date_idx
  on public.gate_incoming_mains(branch_id, incoming_date desc);

create index if not exists gate_incoming_entries_incoming_idx
  on public.gate_incoming_entries(incoming_id, attached_at)
  where removed_at is null;

create or replace function app_private.current_user_is_gate()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(exists (
    select 1
    from public.staff_profiles sp
    join public.branches b on b.id = sp.branch_id
    where sp.user_id = auth.uid()
      and sp.is_active = true
      and b.is_active = true
      and b.branch_type = 'gate'
  ), false);
$$;

create or replace function app_private.create_gate_ledger(
  p_driver_id uuid,
  p_ledger_date date
)
returns public.gate_ledger_mains
language plpgsql
security definer
set search_path = public, app_private
as $$
declare
  v_branch_id text := app_private.current_user_branch_id();
  v_ledger public.gate_ledger_mains%rowtype;
begin
  if auth.uid() is null or not app_private.current_user_is_gate() then
    raise exception 'Gate staff access required';
  end if;
  if not exists(select 1 from public.drivers where id = p_driver_id and active = true) then
    raise exception 'Active driver not found';
  end if;
  insert into public.gate_ledger_mains(branch_id, driver_id, ledger_date, created_by)
  values(v_branch_id, p_driver_id, coalesce(p_ledger_date, current_date), auth.uid())
  returning * into v_ledger;
  return v_ledger;
end;
$$;

create or replace function app_private.attach_parcel_to_gate_ledger(
  p_ledger_id uuid,
  p_tracking_id text
)
returns public.gate_ledger_entries
language plpgsql
security definer
set search_path = public, app_private
as $$
declare
  v_branch_id text := app_private.current_user_branch_id();
  v_ledger public.gate_ledger_mains%rowtype;
  v_parcel public.parcels%rowtype;
  v_entry public.gate_ledger_entries%rowtype;
begin
  if auth.uid() is null or not app_private.current_user_is_gate() then raise exception 'Gate staff access required'; end if;
  if btrim(coalesce(p_tracking_id, '')) = '' then raise exception 'Tracking ID is required'; end if;
  select * into v_ledger from public.gate_ledger_mains where id = p_ledger_id and branch_id = v_branch_id for update;
  if not found then raise exception 'Gate ledger not found'; end if;
  if v_ledger.status <> 'draft' then raise exception 'Settled ledger cannot be edited'; end if;
  select * into v_parcel from public.parcels where tracking_id = btrim(p_tracking_id) for update;
  if not found then raise exception 'Parcel not found'; end if;
  if v_parcel.status in ('partially_split', 'split') then raise exception 'Split parent parcel cannot be attached. Use a child voucher tracking ID.'; end if;
  if v_parcel.status <> 'received' then raise exception 'Only received parcels can be attached'; end if;
  insert into public.gate_ledger_entries(ledger_id, parcel_id, tracking_id_snapshot, destination_town_snapshot, attached_by)
  values(v_ledger.id, v_parcel.id, v_parcel.tracking_id, v_parcel.to_town, auth.uid())
  returning * into v_entry;
  return v_entry;
exception when unique_violation then
  raise exception 'Parcel is already attached to a gate ledger' using errcode = '23505';
end;
$$;

create or replace function app_private.remove_gate_ledger_entry(p_entry_id uuid)
returns void
language plpgsql
security definer
set search_path = public, app_private
as $$
declare v_branch_id text := app_private.current_user_branch_id();
begin
  if auth.uid() is null or not app_private.current_user_is_gate() then raise exception 'Gate staff access required'; end if;
  update public.gate_ledger_entries e
  set removed_at = now(), removed_by = auth.uid()
  from public.gate_ledger_mains m
  where e.id = p_entry_id and e.ledger_id = m.id and m.branch_id = v_branch_id
    and m.status = 'draft' and e.removed_at is null;
  if not found then raise exception 'Editable gate ledger entry not found'; end if;
end;
$$;

create or replace function app_private.settle_gate_ledger(p_ledger_id uuid)
returns public.gate_ledger_mains
language plpgsql
security definer
set search_path = public, app_private
as $$
declare
  v_branch_id text := app_private.current_user_branch_id();
  v_ledger public.gate_ledger_mains%rowtype;
  v_driver public.drivers%rowtype;
begin
  if auth.uid() is null or not app_private.current_user_is_gate() then raise exception 'Gate staff access required'; end if;
  select * into v_ledger from public.gate_ledger_mains where id = p_ledger_id and branch_id = v_branch_id for update;
  if not found then raise exception 'Gate ledger not found'; end if;
  if v_ledger.status <> 'draft' then raise exception 'Ledger is already settled'; end if;
  if not exists(select 1 from public.gate_ledger_entries where ledger_id = v_ledger.id and removed_at is null) then
    raise exception 'Cannot settle an empty ledger';
  end if;
  if exists(
    select 1 from public.gate_ledger_entries e join public.parcels p on p.id = e.parcel_id
    where e.ledger_id = v_ledger.id and e.removed_at is null and p.status <> 'received'
  ) then raise exception 'Ledger contains parcels that are not ready to dispatch'; end if;
  select * into v_driver from public.drivers where id = v_ledger.driver_id;
  update public.parcels p set
    status = 'dispatched', dispatched_at = now(), dispatched_date = now(),
    dispatch_id = v_ledger.id::text, driver_id = v_driver.id::text,
    driver_name = v_driver.name, driver_phone = v_driver.phone, updated_at = now()
  from public.gate_ledger_entries e
  where e.ledger_id = v_ledger.id and e.removed_at is null and e.parcel_id = p.id;
  update public.gate_ledger_mains set status = 'settled', settled_at = now(), updated_at = now()
  where id = v_ledger.id returning * into v_ledger;
  return v_ledger;
end;
$$;

create or replace function app_private.create_gate_incoming(
  p_driver_id uuid,
  p_incoming_date date
)
returns public.gate_incoming_mains
language plpgsql
security definer
set search_path = public, app_private
as $$
declare v_branch_id text := app_private.current_user_branch_id(); v_main public.gate_incoming_mains%rowtype;
begin
  if auth.uid() is null or not app_private.current_user_is_gate() then raise exception 'Gate staff access required'; end if;
  if not exists(select 1 from public.drivers where id = p_driver_id and active = true) then raise exception 'Active driver not found'; end if;
  insert into public.gate_incoming_mains(branch_id, driver_id, incoming_date, created_by)
  values(v_branch_id, p_driver_id, coalesce(p_incoming_date, current_date), auth.uid()) returning * into v_main;
  return v_main;
end;
$$;

create or replace function app_private.attach_existing_gate_incoming_parcel(p_incoming_id uuid, p_tracking_id text)
returns public.gate_incoming_entries
language plpgsql
security definer
set search_path = public, app_private
as $$
declare v_branch_id text := app_private.current_user_branch_id(); v_main public.gate_incoming_mains%rowtype; v_parcel public.parcels%rowtype; v_entry public.gate_incoming_entries%rowtype;
begin
  if auth.uid() is null or not app_private.current_user_is_gate() then raise exception 'Gate staff access required'; end if;
  select * into v_main from public.gate_incoming_mains where id = p_incoming_id and branch_id = v_branch_id for update;
  if not found then raise exception 'Incoming list not found'; end if;
  if v_main.driver_payment_status = 'paid' then raise exception 'Paid incoming list cannot be edited'; end if;
  select * into v_parcel from public.parcels where tracking_id = btrim(coalesce(p_tracking_id, '')) for update;
  if not found then raise exception 'Parcel not found'; end if;
  if v_parcel.status in ('partially_split', 'split') then raise exception 'Split parent parcel cannot be received. Use a child voucher tracking ID.'; end if;
  if v_parcel.status = 'claimed' then raise exception 'Claimed parcel cannot be received again'; end if;
  if v_parcel.status <> 'dispatched' then raise exception 'Only dispatched parcels can be received'; end if;
  insert into public.gate_incoming_entries(incoming_id, parcel_id, tracking_id, entry_type, receiver_name, receiver_phone, destination_town, payment_status, total_charges, cash_advance, note, attached_by)
  values(v_main.id, v_parcel.id, v_parcel.tracking_id, 'existing_parcel', v_parcel.receiver_name, v_parcel.receiver_phone, v_parcel.to_town, v_parcel.payment_status, v_parcel.total_charges, v_parcel.cash_advance, v_parcel.remark, auth.uid())
  returning * into v_entry;
  update public.parcels set status = 'arrived', arrived_at = now(), arrived_branch_id = v_branch_id, arrived_by = auth.uid(), updated_at = now() where id = v_parcel.id;
  return v_entry;
exception when unique_violation then raise exception 'Parcel is already attached to an incoming list' using errcode = '23505';
end;
$$;

create or replace function app_private.lookup_gate_incoming_parcel(p_incoming_id uuid, p_tracking_id text)
returns jsonb
language plpgsql
security definer
set search_path = public, app_private
as $$
declare v_branch_id text := app_private.current_user_branch_id(); v_main public.gate_incoming_mains%rowtype; v_parcel public.parcels%rowtype;
begin
  if auth.uid() is null or not app_private.current_user_is_gate() then raise exception 'Gate staff access required'; end if;
  select * into v_main from public.gate_incoming_mains where id = p_incoming_id and branch_id = v_branch_id;
  if not found then raise exception 'Incoming list not found'; end if;
  if v_main.driver_payment_status = 'paid' then raise exception 'Paid incoming list cannot be edited'; end if;
  select * into v_parcel from public.parcels where tracking_id = btrim(coalesce(p_tracking_id, ''));
  if not found then raise exception 'Parcel not found'; end if;
  if v_parcel.status in ('partially_split', 'split') then raise exception 'Split parent parcel cannot be received. Use a child voucher tracking ID.'; end if;
  if v_parcel.status = 'claimed' then raise exception 'Claimed parcel cannot be received again'; end if;
  if v_parcel.status <> 'dispatched' then raise exception 'Only dispatched parcels can be received'; end if;
  if exists(select 1 from public.gate_incoming_entries where parcel_id = v_parcel.id and removed_at is null) then raise exception 'Parcel is already attached to an incoming list'; end if;
  return jsonb_build_object(
    'tracking_id', v_parcel.tracking_id,
    'receiver_name', v_parcel.receiver_name,
    'receiver_phone', v_parcel.receiver_phone,
    'destination_town', v_parcel.to_town,
    'payment_status', v_parcel.payment_status,
    'total_charges', v_parcel.total_charges,
    'cash_advance', v_parcel.cash_advance,
    'note', v_parcel.remark
  );
end;
$$;

create or replace function app_private.add_manual_gate_incoming_parcel(
  p_incoming_id uuid, p_receiver_name text, p_receiver_phone text, p_destination_town text,
  p_payment_status text, p_total_charges numeric, p_cash_advance numeric, p_note text
)
returns public.gate_incoming_entries
language plpgsql
security definer
set search_path = public, app_private
as $$
declare v_branch_id text := app_private.current_user_branch_id(); v_main public.gate_incoming_mains%rowtype; v_entry public.gate_incoming_entries%rowtype;
begin
  if auth.uid() is null or not app_private.current_user_is_gate() then raise exception 'Gate staff access required'; end if;
  select * into v_main from public.gate_incoming_mains where id = p_incoming_id and branch_id = v_branch_id for update;
  if not found then raise exception 'Incoming list not found'; end if;
  if v_main.driver_payment_status = 'paid' then raise exception 'Paid incoming list cannot be edited'; end if;
  if btrim(coalesce(p_receiver_name, '')) = '' or btrim(coalesce(p_receiver_phone, '')) = '' or btrim(coalesce(p_destination_town, '')) = '' then raise exception 'Receiver, phone and destination are required'; end if;
  if p_payment_status not in ('paid', 'unpaid') then raise exception 'Invalid payment status'; end if;
  if coalesce(p_total_charges, 0) < 0 or coalesce(p_cash_advance, 0) < 0 then raise exception 'Amounts cannot be negative'; end if;
  insert into public.gate_incoming_entries(incoming_id, entry_type, receiver_name, receiver_phone, destination_town, payment_status, total_charges, cash_advance, note, attached_by)
  values(v_main.id, 'manual', btrim(p_receiver_name), btrim(p_receiver_phone), btrim(p_destination_town), p_payment_status, coalesce(p_total_charges, 0), coalesce(p_cash_advance, 0), nullif(btrim(coalesce(p_note, '')), ''), auth.uid())
  returning * into v_entry;
  return v_entry;
end;
$$;

create or replace function app_private.remove_gate_incoming_entry(p_entry_id uuid)
returns void language plpgsql security definer set search_path = public, app_private as $$
declare v_branch_id text := app_private.current_user_branch_id(); v_entry public.gate_incoming_entries%rowtype;
begin
  if auth.uid() is null or not app_private.current_user_is_gate() then raise exception 'Gate staff access required'; end if;
  select e.* into v_entry
  from public.gate_incoming_entries e
  join public.gate_incoming_mains m on m.id = e.incoming_id
  where e.id = p_entry_id and m.branch_id = v_branch_id and m.driver_payment_status = 'unpaid' and e.removed_at is null and e.claimed = false
  for update of e;
  if not found then raise exception 'Editable incoming entry not found'; end if;

  update public.gate_incoming_entries
  set removed_at = now(), removed_by = auth.uid(), updated_at = now()
  where id = v_entry.id;

  if v_entry.parcel_id is not null then
    update public.parcels
    set status = 'dispatched', arrived_at = null, arrived_branch_id = null, arrived_by = null, updated_at = now()
    where id = v_entry.parcel_id and status = 'arrived' and arrived_branch_id = v_branch_id;
    if not found then raise exception 'Parcel arrival state changed; entry cannot be removed'; end if;
  end if;
end; $$;

create or replace function app_private.update_manual_gate_incoming_parcel(
  p_entry_id uuid, p_receiver_name text, p_receiver_phone text, p_destination_town text,
  p_payment_status text, p_total_charges numeric, p_cash_advance numeric, p_note text
)
returns public.gate_incoming_entries language plpgsql security definer set search_path = public, app_private as $$
declare v_branch_id text := app_private.current_user_branch_id(); v_entry public.gate_incoming_entries%rowtype;
begin
  if auth.uid() is null or not app_private.current_user_is_gate() then raise exception 'Gate staff access required'; end if;
  if btrim(coalesce(p_receiver_name, '')) = '' or btrim(coalesce(p_receiver_phone, '')) = '' or btrim(coalesce(p_destination_town, '')) = '' then raise exception 'Receiver, phone and destination are required'; end if;
  if p_payment_status not in ('paid', 'unpaid') then raise exception 'Invalid payment status'; end if;
  if coalesce(p_total_charges, 0) < 0 or coalesce(p_cash_advance, 0) < 0 then raise exception 'Amounts cannot be negative'; end if;
  update public.gate_incoming_entries e set receiver_name = btrim(p_receiver_name), receiver_phone = btrim(p_receiver_phone), destination_town = btrim(p_destination_town), payment_status = p_payment_status, total_charges = coalesce(p_total_charges, 0), cash_advance = coalesce(p_cash_advance, 0), note = nullif(btrim(coalesce(p_note, '')), ''), updated_at = now()
  from public.gate_incoming_mains m where e.id = p_entry_id and e.incoming_id = m.id and m.branch_id = v_branch_id and m.driver_payment_status = 'unpaid' and e.entry_type = 'manual' and e.claimed = false and e.removed_at is null
  returning e.* into v_entry;
  if not found then raise exception 'Editable manual incoming entry not found'; end if;
  return v_entry;
end; $$;

create or replace function app_private.mark_gate_incoming_driver_paid(p_incoming_id uuid, p_amount numeric, p_note text)
returns public.gate_incoming_mains language plpgsql security definer set search_path = public, app_private as $$
declare v_branch_id text := app_private.current_user_branch_id(); v_main public.gate_incoming_mains%rowtype;
begin
  if auth.uid() is null or not app_private.current_user_is_gate() then raise exception 'Gate staff access required'; end if;
  if coalesce(p_amount, -1) < 0 then raise exception 'Driver payment amount is required'; end if;
  update public.gate_incoming_mains set driver_payment_status = 'paid', driver_payment_amount = p_amount, driver_paid_at = now(), driver_paid_by = auth.uid(), driver_payment_note = nullif(btrim(coalesce(p_note, '')), ''), updated_at = now()
  where id = p_incoming_id and branch_id = v_branch_id and driver_payment_status = 'unpaid' returning * into v_main;
  if not found then raise exception 'Unpaid incoming list not found'; end if;
  return v_main;
end; $$;

create or replace function app_private.mark_gate_incoming_entry_claimed(p_entry_id uuid, p_claim_note text, p_payment_status text default null)
returns public.gate_incoming_entries language plpgsql security definer set search_path = public, app_private as $$
declare v_branch_id text := app_private.current_user_branch_id(); v_entry public.gate_incoming_entries%rowtype;
begin
  if auth.uid() is null or not app_private.current_user_is_gate() then raise exception 'Gate staff access required'; end if;
  if btrim(coalesce(p_claim_note, '')) = '' then raise exception 'Claim note is required'; end if;
  select e.* into v_entry from public.gate_incoming_entries e join public.gate_incoming_mains m on m.id = e.incoming_id where e.id = p_entry_id and m.branch_id = v_branch_id and e.removed_at is null for update of e;
  if not found then raise exception 'Incoming entry not found'; end if;
  if v_entry.claimed then raise exception 'Parcel is already claimed'; end if;
  if v_entry.entry_type = 'manual' and p_payment_status is not null and p_payment_status not in ('paid', 'unpaid') then raise exception 'Invalid payment status'; end if;
  update public.gate_incoming_entries set claimed = true, claimed_at = now(), claimed_by = auth.uid(), claim_note = btrim(p_claim_note), payment_status = case when entry_type = 'manual' then coalesce(p_payment_status, payment_status) else payment_status end, updated_at = now() where id = v_entry.id returning * into v_entry;
  if v_entry.parcel_id is not null then update public.parcels set status = 'claimed', claimed_at = now(), claimed_by = auth.uid(), claim_note = btrim(p_claim_note), updated_at = now() where id = v_entry.parcel_id; end if;
  return v_entry;
end; $$;

create or replace function public.create_gate_ledger(p_driver_id uuid, p_ledger_date date) returns public.gate_ledger_mains language sql security invoker set search_path = public, app_private as $$ select app_private.create_gate_ledger(p_driver_id, p_ledger_date); $$;
create or replace function public.attach_parcel_to_gate_ledger(p_ledger_id uuid, p_tracking_id text) returns public.gate_ledger_entries language sql security invoker set search_path = public, app_private as $$ select app_private.attach_parcel_to_gate_ledger(p_ledger_id, p_tracking_id); $$;
create or replace function public.remove_gate_ledger_entry(p_entry_id uuid) returns void language sql security invoker set search_path = public, app_private as $$ select app_private.remove_gate_ledger_entry(p_entry_id); $$;
create or replace function public.settle_gate_ledger(p_ledger_id uuid) returns public.gate_ledger_mains language sql security invoker set search_path = public, app_private as $$ select app_private.settle_gate_ledger(p_ledger_id); $$;
create or replace function public.create_gate_incoming(p_driver_id uuid, p_incoming_date date) returns public.gate_incoming_mains language sql security invoker set search_path = public, app_private as $$ select app_private.create_gate_incoming(p_driver_id, p_incoming_date); $$;
create or replace function public.lookup_gate_incoming_parcel(p_incoming_id uuid, p_tracking_id text) returns jsonb language sql security invoker set search_path = public, app_private as $$ select app_private.lookup_gate_incoming_parcel(p_incoming_id, p_tracking_id); $$;
create or replace function public.attach_existing_gate_incoming_parcel(p_incoming_id uuid, p_tracking_id text) returns public.gate_incoming_entries language sql security invoker set search_path = public, app_private as $$ select app_private.attach_existing_gate_incoming_parcel(p_incoming_id, p_tracking_id); $$;
create or replace function public.add_manual_gate_incoming_parcel(p_incoming_id uuid, p_receiver_name text, p_receiver_phone text, p_destination_town text, p_payment_status text, p_total_charges numeric, p_cash_advance numeric, p_note text) returns public.gate_incoming_entries language sql security invoker set search_path = public, app_private as $$ select app_private.add_manual_gate_incoming_parcel(p_incoming_id, p_receiver_name, p_receiver_phone, p_destination_town, p_payment_status, p_total_charges, p_cash_advance, p_note); $$;
create or replace function public.remove_gate_incoming_entry(p_entry_id uuid) returns void language sql security invoker set search_path = public, app_private as $$ select app_private.remove_gate_incoming_entry(p_entry_id); $$;
create or replace function public.update_manual_gate_incoming_parcel(p_entry_id uuid, p_receiver_name text, p_receiver_phone text, p_destination_town text, p_payment_status text, p_total_charges numeric, p_cash_advance numeric, p_note text) returns public.gate_incoming_entries language sql security invoker set search_path = public, app_private as $$ select app_private.update_manual_gate_incoming_parcel(p_entry_id, p_receiver_name, p_receiver_phone, p_destination_town, p_payment_status, p_total_charges, p_cash_advance, p_note); $$;
create or replace function public.mark_gate_incoming_driver_paid(p_incoming_id uuid, p_amount numeric, p_note text) returns public.gate_incoming_mains language sql security invoker set search_path = public, app_private as $$ select app_private.mark_gate_incoming_driver_paid(p_incoming_id, p_amount, p_note); $$;
create or replace function public.mark_gate_incoming_entry_claimed(p_entry_id uuid, p_claim_note text, p_payment_status text default null) returns public.gate_incoming_entries language sql security invoker set search_path = public, app_private as $$ select app_private.mark_gate_incoming_entry_claimed(p_entry_id, p_claim_note, p_payment_status); $$;

alter table public.gate_ledger_mains enable row level security;
alter table public.gate_ledger_entries enable row level security;
alter table public.gate_incoming_mains enable row level security;
alter table public.gate_incoming_entries enable row level security;

revoke all on public.gate_ledger_mains, public.gate_ledger_entries, public.gate_incoming_mains, public.gate_incoming_entries from anon;
revoke all on public.gate_ledger_mains, public.gate_ledger_entries, public.gate_incoming_mains, public.gate_incoming_entries from authenticated;
grant select on public.gate_ledger_mains, public.gate_ledger_entries, public.gate_incoming_mains, public.gate_incoming_entries to authenticated;

drop policy if exists gate_ledger_mains_select_own_branch on public.gate_ledger_mains;
create policy gate_ledger_mains_select_own_branch on public.gate_ledger_mains for select to authenticated using (branch_id = app_private.current_user_branch_id());
drop policy if exists gate_ledger_entries_select_own_branch on public.gate_ledger_entries;
create policy gate_ledger_entries_select_own_branch on public.gate_ledger_entries for select to authenticated using (exists(select 1 from public.gate_ledger_mains m where m.id = ledger_id and m.branch_id = app_private.current_user_branch_id()));
drop policy if exists gate_incoming_mains_select_own_branch on public.gate_incoming_mains;
create policy gate_incoming_mains_select_own_branch on public.gate_incoming_mains for select to authenticated using (branch_id = app_private.current_user_branch_id());
drop policy if exists gate_incoming_entries_select_own_branch on public.gate_incoming_entries;
create policy gate_incoming_entries_select_own_branch on public.gate_incoming_entries for select to authenticated using (exists(select 1 from public.gate_incoming_mains m where m.id = incoming_id and m.branch_id = app_private.current_user_branch_id()));

revoke execute on function
  app_private.current_user_role(),
  app_private.current_user_branch_id(),
  app_private.is_admin(),
  app_private.can_access_branch(text),
  app_private.can_access_city_code(text),
  app_private.current_user_is_gate(),
  app_private.create_gate_ledger(uuid, date),
  app_private.attach_parcel_to_gate_ledger(uuid, text),
  app_private.remove_gate_ledger_entry(uuid),
  app_private.settle_gate_ledger(uuid),
  app_private.create_gate_incoming(uuid, date),
  app_private.attach_existing_gate_incoming_parcel(uuid, text),
  app_private.lookup_gate_incoming_parcel(uuid, text),
  app_private.add_manual_gate_incoming_parcel(uuid, text, text, text, text, numeric, numeric, text),
  app_private.remove_gate_incoming_entry(uuid),
  app_private.update_manual_gate_incoming_parcel(uuid, text, text, text, text, numeric, numeric, text),
  app_private.mark_gate_incoming_driver_paid(uuid, numeric, text),
  app_private.mark_gate_incoming_entry_claimed(uuid, text, text)
from public, anon;

grant execute on function
  app_private.current_user_role(),
  app_private.current_user_branch_id(),
  app_private.is_admin(),
  app_private.can_access_branch(text),
  app_private.can_access_city_code(text),
  app_private.current_user_is_gate(),
  app_private.create_gate_ledger(uuid, date),
  app_private.attach_parcel_to_gate_ledger(uuid, text),
  app_private.remove_gate_ledger_entry(uuid),
  app_private.settle_gate_ledger(uuid),
  app_private.create_gate_incoming(uuid, date),
  app_private.attach_existing_gate_incoming_parcel(uuid, text),
  app_private.lookup_gate_incoming_parcel(uuid, text),
  app_private.add_manual_gate_incoming_parcel(uuid, text, text, text, text, numeric, numeric, text),
  app_private.remove_gate_incoming_entry(uuid),
  app_private.update_manual_gate_incoming_parcel(uuid, text, text, text, text, numeric, numeric, text),
  app_private.mark_gate_incoming_driver_paid(uuid, numeric, text),
  app_private.mark_gate_incoming_entry_claimed(uuid, text, text)
to authenticated, service_role;
revoke execute on function public.create_gate_ledger(uuid, date), public.attach_parcel_to_gate_ledger(uuid, text), public.remove_gate_ledger_entry(uuid), public.settle_gate_ledger(uuid), public.create_gate_incoming(uuid, date), public.lookup_gate_incoming_parcel(uuid, text), public.attach_existing_gate_incoming_parcel(uuid, text), public.add_manual_gate_incoming_parcel(uuid, text, text, text, text, numeric, numeric, text), public.remove_gate_incoming_entry(uuid), public.update_manual_gate_incoming_parcel(uuid, text, text, text, text, numeric, numeric, text), public.mark_gate_incoming_driver_paid(uuid, numeric, text), public.mark_gate_incoming_entry_claimed(uuid, text, text) from public, anon;
grant execute on function public.create_gate_ledger(uuid, date), public.attach_parcel_to_gate_ledger(uuid, text), public.remove_gate_ledger_entry(uuid), public.settle_gate_ledger(uuid), public.create_gate_incoming(uuid, date), public.lookup_gate_incoming_parcel(uuid, text), public.attach_existing_gate_incoming_parcel(uuid, text), public.add_manual_gate_incoming_parcel(uuid, text, text, text, text, numeric, numeric, text), public.remove_gate_incoming_entry(uuid), public.update_manual_gate_incoming_parcel(uuid, text, text, text, text, numeric, numeric, text), public.mark_gate_incoming_driver_paid(uuid, numeric, text), public.mark_gate_incoming_entry_claimed(uuid, text, text) to authenticated;

drop policy if exists drivers_select_active_gate_staff on public.drivers;
create policy drivers_select_active_gate_staff on public.drivers for select to authenticated using (active = true and app_private.current_user_is_gate());
