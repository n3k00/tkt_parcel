-- TKT Transport System Supabase schema prototype.
-- Apply this in Supabase SQL editor after creating a project.

create extension if not exists pgcrypto;

create schema if not exists app_private;

revoke all on schema app_private from public;
grant usage on schema app_private to authenticated, service_role;

create table if not exists public.branches (
  id text primary key,
  town_name text not null,
  city_code text not null unique,
  branch_type text not null default 'main'
    check (branch_type in ('main', 'gate')),
  address text,
  phone_numbers text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.towns (
  id uuid primary key default gen_random_uuid(),
  name_mm text not null,
  name_en text,
  code text,
  sort_order integer not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint towns_name_mm_not_empty check (length(trim(name_mm)) > 0),
  constraint towns_code_not_empty check (
    code is null
    or length(trim(code)) > 0
  ),
  constraint towns_sort_order_positive check (sort_order > 0),
  constraint towns_name_mm_unique unique (name_mm),
  constraint towns_sort_order_unique unique (sort_order)
);

create unique index if not exists towns_code_unique_idx
  on public.towns(lower(trim(code)))
  where code is not null and length(trim(code)) > 0;

create index if not exists towns_active_sort_order_idx
  on public.towns(active, sort_order);

alter table public.branches
  add column if not exists branch_type text not null default 'main',
  add column if not exists address text,
  add column if not exists phone_numbers text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'branches_branch_type_check'
      and conrelid = 'public.branches'::regclass
  ) then
    alter table public.branches
      add constraint branches_branch_type_check
      check (branch_type in ('main', 'gate'));
  end if;
end;
$$;

create table if not exists public.staff_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  branch_id text references public.branches(id),
  role text not null default 'staff' check (role in ('staff', 'admin')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.devices (
  id text primary key,
  branch_id text references public.branches(id),
  name text,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.parcel_counters (
  city_code text not null,
  service_date date not null,
  running_number integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (city_code, service_date)
);

create table if not exists public.parcels (
  id uuid primary key default gen_random_uuid(),
  client_parcel_id text not null unique,
  tracking_id text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  device_id text references public.devices(id),
  branch_id text references public.branches(id),
  from_town text not null,
  to_town text not null,
  city_code text not null,
  account_code text,
  sender_name text not null,
  sender_phone text not null,
  receiver_name text not null,
  receiver_phone text not null,
  parcel_type text not null,
  number_of_parcels integer not null check (number_of_parcels > 0),
  total_charges numeric(12, 2) not null check (total_charges >= 0),
  payment_status text not null check (payment_status in ('paid', 'unpaid')),
  cash_advance numeric(12, 2) not null default 0 check (cash_advance >= 0),
  remark text,
  status text not null default 'received'
    constraint parcels_status_check
    check (status in ('received', 'partially_split', 'dispatched', 'arrived', 'claimed', 'cancelled', 'split')),
  dispatched_at timestamptz,
  arrived_at timestamptz,
  claimed_at timestamptz,
  cancelled_at timestamptz,
  dispatch_id text,
  driver_id text,
  driver_name text,
  driver_phone text,
  dispatched_date timestamptz,
  claim_note text,
  parent_parcel_id uuid references public.parcels(id),
  split_index text,
  split_count integer check (split_count is null or split_count > 0),
  split_created_at timestamptz,
  split_created_by uuid references auth.users(id)
);

alter table public.parcels
  add column if not exists parent_parcel_id uuid references public.parcels(id),
  add column if not exists split_index text,
  add column if not exists split_count integer,
  add column if not exists split_created_at timestamptz,
  add column if not exists split_created_by uuid references auth.users(id);

do $$
declare
  v_constraint_name text;
begin
  select conname into v_constraint_name
  from pg_constraint
  where conrelid = 'public.parcels'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) like '%status%'
    and pg_get_constraintdef(oid) like '%received%'
    and pg_get_constraintdef(oid) like '%cancelled%'
  limit 1;

  if v_constraint_name is not null and v_constraint_name <> 'parcels_status_check' then
    execute format('alter table public.parcels drop constraint %I', v_constraint_name);
  end if;

  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.parcels'::regclass
      and conname = 'parcels_status_check'
      and pg_get_constraintdef(oid) not like '%partially_split%'
  ) then
    alter table public.parcels drop constraint parcels_status_check;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.parcels'::regclass
      and conname = 'parcels_status_check'
  ) then
    alter table public.parcels
      add constraint parcels_status_check
      check (status in ('received', 'partially_split', 'dispatched', 'arrived', 'claimed', 'cancelled', 'split'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.parcels'::regclass
      and conname = 'parcels_split_count_check'
  ) then
    alter table public.parcels
      add constraint parcels_split_count_check
      check (split_count is null or split_count > 0);
  end if;
end;
$$;

create index if not exists staff_profiles_branch_id_idx
  on public.staff_profiles(branch_id);

create index if not exists parcels_updated_at_idx
  on public.parcels(updated_at desc);

create index if not exists parcels_sync_lookup_idx
  on public.parcels(branch_id, updated_at desc);

create index if not exists parcels_status_idx
  on public.parcels(status);

create index if not exists parcels_branch_id_idx
  on public.parcels(branch_id);

create index if not exists parcels_created_by_idx
  on public.parcels(created_by);

create index if not exists parcels_parent_parcel_id_idx
  on public.parcels(parent_parcel_id);

create unique index if not exists parcels_parent_split_index_unique
  on public.parcels(parent_parcel_id, split_index)
  where parent_parcel_id is not null and split_index is not null;

insert into public.branches (id, town_name, city_code, branch_type)
values
  ('source_tgi', U&'\1010\1031\102C\1004\103A\1000\103C\102E\1038', 'TGI', 'main'),
  ('source_lso', U&'\101C\102C\1038\101B\103E\102D\102F\1038', 'LSO', 'main'),
  ('source_tcl', U&'\1010\102C\1001\103B\102E\101C\102D\1010\103A', 'TCL', 'main'),
  ('gate_llm', U&'\101C\103D\102D\102F\1004\103A\101C\1004\103A', 'LLM', 'gate'),
  ('gate_kgt', U&'\1000\103B\102D\102F\1004\103A\1038\1010\102F\1036', 'KGT', 'gate')
on conflict (id) do update set
  town_name = excluded.town_name,
  city_code = excluded.city_code,
  branch_type = excluded.branch_type,
  updated_at = now();

insert into public.parcel_counters (city_code, service_date, running_number)
values
  ('LLM', (now() at time zone 'Asia/Yangon')::date, 0),
  ('KGT', (now() at time zone 'Asia/Yangon')::date, 0)
on conflict (city_code, service_date) do nothing;

insert into public.towns (name_mm, name_en, code, sort_order)
values
  ('ကာလိ', 'KarLi', 'KLI', 1),
  ('ကွန်ဟိန်း', 'Kunhing', 'KHG', 2),
  ('ကောင်းလမ်း', 'Kaung Lan', 'KGL', 3),
  ('ကျိုင်းတုံ', 'Kyaing Tong', 'KGT', 4),
  ('ကျေးသီး', 'Kyethi', 'KYT', 5),
  ('ကုန်းသာ', 'Kone Thar', 'KTH', 6),
  ('ခိုလမ်', 'Kho Lam', 'KLM', 7),
  ('ဆင်မောင်း', 'Hsin Mawng', 'HMG', 8),
  ('တာကော်', 'Ta Kaw', 'TKW', 9),
  ('တာချီလိတ်', 'Tachileik', 'TCL', 10),
  ('တာလေ', 'Tar Lay', 'TLY', 11),
  ('တောင်ကြီး', 'Taunggyi', 'TGI', 12),
  ('တုံတာ', 'Tong Tar', 'TTA', 13),
  ('နမ့်စန်', 'Namsang', 'NSG', 14),
  ('နမ့်ပေါင်', 'Nampawng', 'NPG', 15),
  ('နမ့်လန်', 'Nam Lan', 'NML', 16),
  ('နောင်မွန်', 'NawngMon', 'NWM', 17),
  ('ပင်လုံ', 'Panglong', 'PLG', 18),
  ('ပန်ကေသု', 'Pang Kay Tu', 'PKT', 19),
  ('မိုင်းကိုင်', 'Mong Kung', 'MGK', 20),
  ('မိုင်းစံ', 'Mong San', 'MGS', 21),
  ('မိုင်းနန်း', 'Mong Nang', 'MGN', 22),
  ('မိုင်းနောင်', 'Mong Nawng', 'MGW', 23),
  ('မိုင်းပွန်', 'Mong Pawn', 'MGP', 24),
  ('မိုင်းပျဥ်း', 'Mong Ping', 'MPG', 25),
  ('မိုင်းဖြတ်', 'Mong Hpyak', 'MHP', 26),
  ('မိုင်းရယ်', 'Mong Yai', 'MGY', 27),
  ('လားရှိုး', 'Lashio', 'LSO', 28),
  ('လဲချား', 'Laihka', 'LHK', 29),
  ('လွိုင်လင်', 'Loilem', 'LLM', 30),
  ('ဝမ်စိမ်း', 'Wan Hke', 'WHK', 31),
  ('ဝမ်ဟိုင်း', 'Wan Hai', 'WHA', 32),
  ('ဟိုပုံး', 'Hopong', 'HPG', 33)
on conflict (name_mm) do update set
  name_en = excluded.name_en,
  code = excluded.code,
  sort_order = excluded.sort_order,
  updated_at = now();

create or replace function app_private.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select sp.role
  from public.staff_profiles sp
  where sp.user_id = auth.uid()
    and sp.is_active = true
  limit 1;
$$;

create or replace function app_private.current_user_branch_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select sp.branch_id
  from public.staff_profiles sp
  where sp.user_id = auth.uid()
    and sp.is_active = true
  limit 1;
$$;

create or replace function app_private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(app_private.current_user_role() = 'admin', false);
$$;

create or replace function app_private.can_access_branch(p_branch_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    auth.uid() is not null
    and p_branch_id is not null
    and exists (
      select 1
      from public.staff_profiles sp
      where sp.user_id = auth.uid()
        and sp.is_active = true
        and (
          sp.role = 'admin'
          or sp.branch_id = p_branch_id
        )
    ),
    false
  );
$$;

create or replace function app_private.can_access_city_code(p_city_code text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    auth.uid() is not null
    and p_city_code is not null
    and exists (
      select 1
      from public.branches b
      join public.staff_profiles sp on sp.branch_id = b.id or sp.role = 'admin'
      where sp.user_id = auth.uid()
        and sp.is_active = true
        and (
          sp.role = 'admin'
          or upper(trim(b.city_code)) = upper(trim(p_city_code))
        )
    ),
    false
  );
$$;

revoke execute on all functions in schema app_private from authenticated, service_role;

grant execute on function
  app_private.current_user_role(),
  app_private.current_user_branch_id(),
  app_private.is_admin(),
  app_private.can_access_branch(text),
  app_private.can_access_city_code(text)
to authenticated, service_role;

alter table public.staff_profiles enable row level security;
alter table public.branches enable row level security;
alter table public.towns enable row level security;
alter table public.devices enable row level security;
alter table public.parcel_counters enable row level security;
alter table public.parcels enable row level security;

-- Harden Data API access. Supabase projects may have broad default grants on
-- public tables; keep anon out and give authenticated users only app-required
-- privileges. RLS policies below still decide which rows are visible/mutable.
revoke all on table public.staff_profiles from anon;
revoke all on table public.branches from anon;
revoke all on table public.towns from anon;
revoke all on table public.devices from anon;
revoke all on table public.parcel_counters from anon;
revoke all on table public.parcels from anon;

revoke all on table public.staff_profiles from authenticated;
revoke all on table public.branches from authenticated;
revoke all on table public.towns from authenticated;
revoke all on table public.devices from authenticated;
revoke all on table public.parcel_counters from authenticated;
revoke all on table public.parcels from authenticated;

grant select on public.staff_profiles to authenticated;
grant select on public.branches to authenticated;
grant update (address, phone_numbers, updated_at) on public.branches to authenticated;
grant select on public.towns to authenticated;
grant select, insert, update on public.devices to authenticated;
grant select, insert, update on public.parcel_counters to authenticated;
grant select, insert, update on public.parcels to authenticated;

drop policy if exists staff_profiles_select_own_or_admin on public.staff_profiles;
create policy staff_profiles_select_own_or_admin
on public.staff_profiles
for select
to authenticated
using (
  (select auth.uid()) = user_id
  or app_private.is_admin()
);

drop policy if exists staff_profiles_admin_write on public.staff_profiles;
create policy staff_profiles_admin_write
on public.staff_profiles
for all
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

drop policy if exists branches_select_by_role on public.branches;
create policy branches_select_by_role
on public.branches
for select
to authenticated
using (
  app_private.is_admin()
  or app_private.current_user_branch_id() = id
);

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'branches'
      and policyname = 'branches_select_active'
  ) then
    execute $policy$
      create policy branches_select_active
      on public.branches
      for select
      to authenticated
      using (is_active = true)
    $policy$;
  end if;
end;
$$;

drop policy if exists branches_admin_write on public.branches;
create policy branches_admin_write
on public.branches
for all
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

drop policy if exists branches_staff_update_own_profile on public.branches;
create policy branches_staff_update_own_profile
on public.branches
for update
to authenticated
using (
  app_private.current_user_branch_id() = id
)
with check (
  app_private.current_user_branch_id() = id
);

drop policy if exists towns_select_active_or_admin on public.towns;
create policy towns_select_active_or_admin
on public.towns
for select
to authenticated
using (
  active = true
  or app_private.is_admin()
);

drop policy if exists devices_select_by_branch on public.devices;
create policy devices_select_by_branch
on public.devices
for select
to authenticated
using (app_private.can_access_branch(branch_id));

drop policy if exists devices_write_by_branch on public.devices;
create policy devices_write_by_branch
on public.devices
for all
to authenticated
using (app_private.can_access_branch(branch_id))
with check (app_private.can_access_branch(branch_id));

drop policy if exists parcel_counters_select_by_branch_city on public.parcel_counters;
create policy parcel_counters_select_by_branch_city
on public.parcel_counters
for select
to authenticated
using (app_private.can_access_city_code(city_code));

drop policy if exists parcel_counters_insert_by_branch_city on public.parcel_counters;
create policy parcel_counters_insert_by_branch_city
on public.parcel_counters
for insert
to authenticated
with check (app_private.can_access_city_code(city_code));

drop policy if exists parcel_counters_update_by_branch_city on public.parcel_counters;
create policy parcel_counters_update_by_branch_city
on public.parcel_counters
for update
to authenticated
using (app_private.can_access_city_code(city_code))
with check (app_private.can_access_city_code(city_code));

drop policy if exists parcels_select_by_branch on public.parcels;
create policy parcels_select_by_branch
on public.parcels
for select
to authenticated
using (app_private.can_access_branch(branch_id));

drop policy if exists parcels_insert_by_branch on public.parcels;
create policy parcels_insert_by_branch
on public.parcels
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and created_by = (select auth.uid())
  and app_private.can_access_branch(branch_id)
);

drop policy if exists parcels_update_by_branch on public.parcels;
create policy parcels_update_by_branch
on public.parcels
for update
to authenticated
using (app_private.can_access_branch(branch_id))
with check (app_private.can_access_branch(branch_id));

create or replace function public.create_parcel_with_counter(
  p_client_parcel_id text,
  p_device_id text,
  p_branch_id text,
  p_from_town text,
  p_to_town text,
  p_city_code text,
  p_sender_name text,
  p_sender_phone text,
  p_receiver_name text,
  p_receiver_phone text,
  p_parcel_type text,
  p_number_of_parcels integer,
  p_total_charges numeric,
  p_payment_status text,
  p_cash_advance numeric default 0,
  p_remark text default null,
  p_created_at timestamptz default now()
)
returns public.parcels
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_branch_city_code text;
  v_service_date date;
  v_running_number integer;
  v_tracking_id text;
  v_parcel public.parcels;
begin
  v_actor := auth.uid();

  if v_actor is null then
    raise exception 'Authentication required';
  end if;

  if btrim(coalesce(p_client_parcel_id, '')) = '' then
    raise exception 'client_parcel_id is required';
  end if;

  select * into v_parcel
  from public.parcels
  where client_parcel_id = p_client_parcel_id;

  if found then
    if not app_private.can_access_branch(v_parcel.branch_id) then
      raise exception 'User is not allowed to access existing parcel %', p_client_parcel_id;
    end if;

    return v_parcel;
  end if;

  if not app_private.can_access_branch(p_branch_id) then
    raise exception 'User is not allowed to create parcels for branch %', p_branch_id;
  end if;

  select upper(trim(city_code)) into v_branch_city_code
  from public.branches
  where id = p_branch_id
    and is_active = true;

  if v_branch_city_code is null then
    raise exception 'Branch % was not found or is inactive', p_branch_id;
  end if;

  if upper(trim(p_city_code)) <> v_branch_city_code then
    raise exception 'city_code % does not match branch %', p_city_code, p_branch_id;
  end if;

  if p_number_of_parcels <= 0 then
    raise exception 'number_of_parcels must be greater than 0';
  end if;

  if p_total_charges < 0 then
    raise exception 'total_charges cannot be negative';
  end if;

  if coalesce(p_cash_advance, 0) < 0 then
    raise exception 'cash_advance cannot be negative';
  end if;

  if p_payment_status not in ('paid', 'unpaid') then
    raise exception 'invalid payment_status: %', p_payment_status;
  end if;

  v_service_date := (p_created_at at time zone 'Asia/Yangon')::date;

  insert into public.parcel_counters (
    city_code,
    service_date,
    running_number
  )
  values (
    v_branch_city_code,
    v_service_date,
    1
  )
  on conflict (city_code, service_date)
  do update set
    running_number = public.parcel_counters.running_number + 1,
    updated_at = now()
  returning running_number into v_running_number;

  v_tracking_id := format(
    '%s-%s-%s',
    v_branch_city_code,
    to_char(v_service_date, 'YYMMDD'),
    lpad(v_running_number::text, 4, '0')
  );

  insert into public.parcels (
    client_parcel_id,
    tracking_id,
    created_at,
    updated_at,
    created_by,
    device_id,
    branch_id,
    from_town,
    to_town,
    city_code,
    account_code,
    sender_name,
    sender_phone,
    receiver_name,
    receiver_phone,
    parcel_type,
    number_of_parcels,
    total_charges,
    payment_status,
    cash_advance,
    remark,
    status
  )
  values (
    p_client_parcel_id,
    v_tracking_id,
    p_created_at,
    p_created_at,
    v_actor,
    p_device_id,
    p_branch_id,
    p_from_town,
    p_to_town,
    v_branch_city_code,
    null,
    p_sender_name,
    p_sender_phone,
    p_receiver_name,
    p_receiver_phone,
    p_parcel_type,
    p_number_of_parcels,
    p_total_charges,
    p_payment_status,
    coalesce(p_cash_advance, 0),
    nullif(trim(coalesce(p_remark, '')), ''),
    'received'
  )
  returning * into v_parcel;

  return v_parcel;
end;
$$;

create or replace function public.split_parcel(
  p_parent_parcel_id uuid,
  p_splits jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_parent public.parcels%rowtype;
  v_child public.parcels%rowtype;
  v_children jsonb := '[]'::jsonb;
  v_item jsonb;
  v_split_count integer;
  v_existing_child_count integer := 0;
  v_existing_child_qty integer := 0;
  v_new_child_count integer;
  v_new_total_qty integer;
  v_split_index integer := 0;
  v_split_code text;
  v_qty integer;
  v_total_qty integer := 0;
  v_total_charges numeric;
  v_cash_advance numeric;
  v_parcel_type text;
  v_remark text;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;

  if p_parent_parcel_id is null then
    raise exception 'Parent parcel is required';
  end if;

  if jsonb_typeof(p_splits) <> 'array' then
    raise exception 'Split rows must be a JSON array';
  end if;

  v_split_count := jsonb_array_length(p_splits);

  if v_split_count <> 1 then
    raise exception 'Progressive split accepts one child row at a time';
  end if;

  select *
  into v_parent
  from public.parcels
  where id = p_parent_parcel_id
  for update;

  if not found then
    raise exception 'Parent parcel not found';
  end if;

  if not app_private.can_access_branch(v_parent.branch_id) then
    raise exception 'Parent parcel branch access denied';
  end if;

  if v_parent.parent_parcel_id is not null then
    raise exception 'Child parcel cannot be split again';
  end if;

  if v_parent.status = 'split' then
    raise exception 'Parent parcel is already fully split';
  end if;

  if v_parent.status not in ('received', 'partially_split') then
    raise exception 'Only received or partially split parcels can be split';
  end if;

  select
    coalesce(sum(number_of_parcels), 0),
    count(*),
    coalesce(max(ascii(split_index) - 64), 0)
  into v_existing_child_qty, v_existing_child_count, v_split_index
  from public.parcels
  where parent_parcel_id = v_parent.id;

  if v_existing_child_count >= 26 or v_split_index >= 26 then
    raise exception 'Split rows cannot exceed 26';
  end if;

  for v_item in
    select value
    from jsonb_array_elements(p_splits)
  loop
    v_qty := nullif(coalesce(v_item->>'number_of_parcels', v_item->>'qty'), '')::integer;
    v_total_charges := nullif(coalesce(v_item->>'total_charges', v_item->>'charges'), '')::numeric;
    v_cash_advance := nullif(coalesce(v_item->>'cash_advance', '0'), '')::numeric;
    v_parcel_type := nullif(btrim(coalesce(v_item->>'parcel_type', v_parent.parcel_type)), '');
    v_remark := nullif(btrim(coalesce(v_item->>'remark', v_parent.remark, '')), '');

    if coalesce(v_qty, 0) <= 0 then
      raise exception 'Split quantity must be greater than 0';
    end if;

    if coalesce(v_total_charges, -1) < 0 then
      raise exception 'Split charges cannot be negative';
    end if;

    if coalesce(v_cash_advance, 0) < 0 then
      raise exception 'Split cash advance cannot be negative';
    end if;

    if v_parcel_type is null then
      raise exception 'Split parcel type is required';
    end if;

    v_total_qty := v_total_qty + v_qty;
  end loop;

  v_new_total_qty := v_existing_child_qty + v_total_qty;
  v_new_child_count := v_existing_child_count + 1;

  if v_new_total_qty > v_parent.number_of_parcels then
    raise exception 'Split quantity total cannot exceed parent quantity';
  end if;

  update public.parcels
  set status = case
        when v_new_total_qty = v_parent.number_of_parcels then 'split'
        else 'partially_split'
      end,
      split_count = v_new_child_count,
      split_created_at = now(),
      split_created_by = v_actor,
      updated_at = now()
  where id = v_parent.id
  returning * into v_parent;

  for v_item in
    select value
    from jsonb_array_elements(p_splits)
  loop
    v_split_index := v_split_index + 1;
    v_split_code := chr(64 + v_split_index);
    v_qty := nullif(coalesce(v_item->>'number_of_parcels', v_item->>'qty'), '')::integer;
    v_total_charges := nullif(coalesce(v_item->>'total_charges', v_item->>'charges'), '')::numeric;
    v_cash_advance := nullif(coalesce(v_item->>'cash_advance', '0'), '')::numeric;
    v_parcel_type := nullif(btrim(coalesce(v_item->>'parcel_type', v_parent.parcel_type)), '');
    v_remark := nullif(btrim(coalesce(v_item->>'remark', v_parent.remark, '')), '');

    insert into public.parcels (
      client_parcel_id,
      tracking_id,
      created_at,
      updated_at,
      created_by,
      device_id,
      branch_id,
      from_town,
      to_town,
      city_code,
      account_code,
      sender_name,
      sender_phone,
      receiver_name,
      receiver_phone,
      parcel_type,
      number_of_parcels,
      total_charges,
      payment_status,
      cash_advance,
      remark,
      status,
      parent_parcel_id,
      split_index,
      split_count,
      split_created_at,
      split_created_by
    )
    values (
      v_parent.client_parcel_id || '-split-' || v_split_code,
      v_parent.tracking_id || '-' || v_split_code,
      now(),
      now(),
      v_actor,
      v_parent.device_id,
      v_parent.branch_id,
      v_parent.from_town,
      v_parent.to_town,
      v_parent.city_code,
      v_parent.account_code,
      v_parent.sender_name,
      v_parent.sender_phone,
      v_parent.receiver_name,
      v_parent.receiver_phone,
      v_parcel_type,
      v_qty,
      v_total_charges,
      v_parent.payment_status,
      coalesce(v_cash_advance, 0),
      v_remark,
      'received',
      v_parent.id,
      v_split_code,
      v_new_child_count,
      now(),
      v_actor
    )
    returning * into v_child;

    v_children := v_children || jsonb_build_array(to_jsonb(v_child));
  end loop;

  update public.parcels
  set split_count = v_new_child_count,
      updated_at = now()
  where parent_parcel_id = v_parent.id;

  return jsonb_build_object(
    'parent', to_jsonb(v_parent),
    'children', v_children
  );
end;
$$;

revoke all on function public.create_parcel_with_counter(text, text, text, text, text, text, text, text, text, text, text, integer, numeric, text, numeric, text, timestamptz) from public;
revoke all on function public.create_parcel_with_counter(text, text, text, text, text, text, text, text, text, text, text, integer, numeric, text, numeric, text, timestamptz) from anon;
grant execute on function public.create_parcel_with_counter(text, text, text, text, text, text, text, text, text, text, text, integer, numeric, text, numeric, text, timestamptz) to authenticated, service_role;
revoke all on function public.split_parcel(uuid, jsonb) from public;
revoke all on function public.split_parcel(uuid, jsonb) from anon;
grant execute on function public.split_parcel(uuid, jsonb) to authenticated, service_role;

comment on table public.staff_profiles is
  'Maps Supabase auth users to TKT staff/admin roles and branch access.';

comment on table public.towns is
  'Central read-only town master list for parcel From/To town choices. Android users should not add towns locally.';

comment on function public.create_parcel_with_counter is
  'Authenticated RPC that idempotently returns an existing client parcel, validates branch access, atomically increments issuing-branch city/date counter, and inserts a parcel with CITY-YYMMDD-NNNN tracking ID.';

comment on function public.split_parcel(uuid, jsonb) is
  'Authenticated RPC that progressively splits one child voucher at a time from a received/partially_split parent, auto-assigning PARENT-A/PARENT-B tracking IDs and marking the parent split only when fully consumed.';
