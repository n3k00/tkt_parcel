-- Run after schema.sql, drivers.sql, and gate_operations.sql in Supabase SQL Editor.
-- This verifies branch seeding, RLS setup, and RPC security mode.
--
-- Note: create_parcel_with_counter now requires an authenticated user with
-- a matching row in public.staff_profiles. Parcel creation should be verified
-- from the app or an authenticated API client after staff accounts are created.

select id, town_name, city_code, branch_type
from public.branches
order by city_code;

select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'staff_profiles',
    'branches',
    'towns',
    'devices',
    'parcel_counters',
    'parcels',
    'drivers'
  )
order by c.relname;

select tablename, policyname, roles, cmd
from pg_policies
where schemaname = 'public'
  and tablename in (
    'staff_profiles',
    'branches',
    'towns',
    'devices',
    'parcel_counters',
    'parcels',
    'drivers'
  )
order by tablename, policyname;

select grantee, table_name, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in (
    'staff_profiles',
    'branches',
    'towns',
    'devices',
    'parcel_counters',
    'parcels',
    'drivers'
  )
  and grantee in ('anon', 'authenticated')
order by table_name, grantee, privilege_type;

select grantee, table_name, column_name, privilege_type
from information_schema.column_privileges
where table_schema = 'public'
  and table_name = 'branches'
  and grantee = 'authenticated'
order by column_name, privilege_type;

select name_mm, name_en, code, sort_order, active
from public.towns
order by sort_order;

select id, name, phone, vehicle_no, driver_type, active
from public.drivers
order by active desc, name;

select column_name, is_nullable, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'parcel_counters'
order by ordinal_position;

select routine_schema, routine_name, security_type
from information_schema.routines
where routine_schema in ('public', 'app_private')
  and routine_name in (
    'create_parcel_with_counter',
    'current_user_role',
    'current_user_branch_id',
    'is_admin',
    'can_access_branch',
    'can_access_city_code'
  )
order by routine_schema, routine_name;

-- Expected:
-- - branches include source_tgi/TGI, source_lso/LSO, source_tcl/TCL as main
--   plus gate_llm/LLM and gate_kgt/KGT as gate
-- - towns include 33 active rows; ခိုလန် is normalized to ခိုလမ်
-- - listed public tables have rls_enabled = true
-- - policies are scoped to authenticated
-- - drivers has RLS enabled, active gate-user read policy, admin write policy,
--   and no anon table privileges
-- - parcel_counters columns are city_code, service_date, running_number, updated_at
-- - public.create_parcel_with_counter has security_type = INVOKER
-- - app_private helper functions have security_type = DEFINER
-- - retrying create_parcel_with_counter with the same client_parcel_id returns
--   the existing parcel without incrementing the counter
-- - generated tracking IDs use CITY-YYMMDD-NNNN with no account-code segment
-- - anon has no table privileges on app public tables
-- - authenticated has only required table privileges:
--   staff_profiles SELECT; branches SELECT plus address/phone_numbers/updated_at UPDATE;
--   towns SELECT; devices/parcel_counters/parcels SELECT, INSERT, UPDATE

select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'gate_ledger_mains',
    'gate_ledger_entries',
    'gate_incoming_mains',
    'gate_incoming_entries'
  )
order by c.relname;

select routine_name, security_type
from information_schema.routines
where routine_schema = 'public'
  and routine_name like '%gate%'
order by routine_name;

-- Expected after gate_operations.sql:
-- - listed gate tables have rls_enabled = true
-- - public gate RPC wrappers have security_type = INVOKER
-- - anon has no gate table privileges
-- - authenticated has SELECT-only gate table privileges; mutations use RPCs
