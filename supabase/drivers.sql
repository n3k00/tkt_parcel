-- Shared drivers table dependency for Android gate operations.
-- Additive only: do not delete existing driver data.

create table if not exists public.drivers (
  id uuid primary key default gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  phone text not null check (btrim(phone) <> ''),
  vehicle_no text not null check (btrim(vehicle_no) <> ''),
  driver_type text not null default 'regular'
    check (driver_type in ('regular', 'guest')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists drivers_active_idx
  on public.drivers(active);

create index if not exists drivers_name_idx
  on public.drivers(name);

create index if not exists drivers_driver_type_idx
  on public.drivers(driver_type);

do $$
begin
  if exists (
    select 1
    from public.drivers
    where active = true
    group by lower(btrim(vehicle_no))
    having count(*) > 1
  ) then
    raise notice 'Skipping drivers_active_vehicle_no_unique_idx because duplicate active vehicle_no values already exist.';
  else
    create unique index if not exists drivers_active_vehicle_no_unique_idx
      on public.drivers(lower(btrim(vehicle_no)))
      where active = true;
  end if;
end;
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'set_drivers_updated_at'
      and tgrelid = 'public.drivers'::regclass
  ) then
    create trigger set_drivers_updated_at
    before update on public.drivers
    for each row
    execute function public.set_updated_at();
  end if;
end;
$$;

alter table public.drivers enable row level security;

revoke all on table public.drivers from anon;
revoke all on table public.drivers from authenticated;

grant select, insert, update on public.drivers to authenticated;

drop policy if exists drivers_select_active_gate_staff on public.drivers;
create policy drivers_select_active_gate_staff
on public.drivers
for select
to authenticated
using (
  active = true
  and exists (
    select 1
    from public.staff_profiles sp
    join public.branches b on b.id = sp.branch_id
    where sp.user_id = (select auth.uid())
      and sp.is_active = true
      and b.is_active = true
      and b.branch_type = 'gate'
  )
);

drop policy if exists drivers_admin_write on public.drivers;
create policy drivers_admin_write
on public.drivers
for all
to authenticated
using (app_private.is_admin())
with check (app_private.is_admin());

comment on table public.drivers is
  'Global driver master shared by gate operations and admin tooling. Android gate users read active drivers only; writes are admin-only.';
