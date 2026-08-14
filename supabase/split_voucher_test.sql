-- Transaction-only Progressive Split Voucher verification.
--
-- Run after schema.sql, drivers.sql, and gate_operations.sql.
-- This script creates temporary test data and finishes with ROLLBACK, so it
-- should not leave parcels, counters, or gate ledger rows behind.
--
-- Requirements:
-- - At least one active gate staff profile exists.
-- - At least one active driver exists.

begin;

create temp table split_voucher_test_context as
select
  sp.user_id,
  sp.branch_id,
  b.city_code,
  d.id as driver_id
from public.staff_profiles sp
join public.branches b on b.id = sp.branch_id
cross join lateral (
  select id
  from public.drivers
  where active = true
  order by created_at, id
  limit 1
) d
where sp.is_active = true
  and b.is_active = true
  and b.branch_type = 'gate'
order by sp.created_at, sp.user_id
limit 1;

grant select on split_voucher_test_context to authenticated;

do $$
begin
  if not exists (select 1 from split_voucher_test_context) then
    raise exception
      'Split voucher test requires one active gate staff profile and one active driver';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  (select user_id::text from split_voucher_test_context limit 1),
  true
);

set local role authenticated;

do $$
declare
  v_context record;
  v_parent public.parcels%rowtype;
  v_child_a public.parcels%rowtype;
  v_child_b public.parcels%rowtype;
  v_child_c public.parcels%rowtype;
  v_ledger public.gate_ledger_mains%rowtype;
  v_parent_attach_was_rejected boolean := false;
  v_over_split_was_rejected boolean := false;
  v_child_tracking_ids_are_unique boolean := false;
  v_child_count integer := 0;
  v_child_qty integer := 0;
  v_child_detail public.gate_ledger_entries%rowtype;
  v_test_key text := 'split-test-' || replace(gen_random_uuid()::text, '-', '');
begin
  select *
  into v_context
  from split_voucher_test_context
  limit 1;

  select *
  into v_parent
  from public.create_parcel_with_counter(
    p_client_parcel_id := v_test_key || '-parent',
    p_device_id := null,
    p_branch_id := v_context.branch_id,
    p_from_town := 'Split Test From',
    p_to_town := 'Split Test To',
    p_city_code := v_context.city_code,
    p_sender_name := 'Split Test Sender',
    p_sender_phone := '09000000001',
    p_receiver_name := 'Split Test Receiver',
    p_receiver_phone := '09000000002',
    p_parcel_type := 'Box',
    p_number_of_parcels := 4,
    p_total_charges := 30000,
    p_payment_status := 'unpaid',
    p_cash_advance := 0,
    p_remark := 'Progressive split parent verification',
    p_created_at := now()
  );

  if v_parent.number_of_parcels <> 4 then
    raise exception 'Expected parent qty 4, got %', v_parent.number_of_parcels;
  end if;

  perform public.split_parcel(
    v_parent.id,
    jsonb_build_array(
      jsonb_build_object(
        'number_of_parcels', 2,
        'total_charges', 11111,
        'cash_advance', 101,
        'parcel_type', 'Box A',
        'remark', 'Manual charges A'
      )
    )
  );

  select *
  into v_parent
  from public.parcels
  where id = v_parent.id;

  if v_parent.status <> 'partially_split' then
    raise exception 'Expected parent status partially_split after A, got %',
      v_parent.status;
  end if;

  if v_parent.split_count <> 1 then
    raise exception 'Expected parent split_count 1 after A, got %',
      v_parent.split_count;
  end if;

  begin
    perform public.split_parcel(
      v_parent.id,
      jsonb_build_array(
        jsonb_build_object(
          'number_of_parcels', 3,
          'total_charges', 99999,
          'cash_advance', 0,
          'parcel_type', 'Too Much'
        )
      )
    );
  exception
    when others then
      if sqlerrm like 'Split quantity total cannot exceed parent quantity%' then
        v_over_split_was_rejected := true;
      else
        raise;
      end if;
  end;

  if v_over_split_was_rejected is not true then
    raise exception 'Expected over-split qty to be rejected';
  end if;

  perform public.split_parcel(
    v_parent.id,
    jsonb_build_array(
      jsonb_build_object(
        'number_of_parcels', 1,
        'total_charges', 22222,
        'cash_advance', 202,
        'parcel_type', 'Box B',
        'remark', 'Manual charges B'
      )
    )
  );

  select *
  into v_parent
  from public.parcels
  where id = v_parent.id;

  if v_parent.status <> 'partially_split' then
    raise exception 'Expected parent status partially_split after B, got %',
      v_parent.status;
  end if;

  perform public.split_parcel(
    v_parent.id,
    jsonb_build_array(
      jsonb_build_object(
        'number_of_parcels', 1,
        'total_charges', 33333,
        'cash_advance', 303,
        'parcel_type', 'Box C',
        'remark', 'Manual charges C'
      )
    )
  );

  select *
  into v_parent
  from public.parcels
  where id = v_parent.id;

  if v_parent.status <> 'split' then
    raise exception 'Expected parent status split after C, got %',
      v_parent.status;
  end if;

  if v_parent.split_count <> 3 then
    raise exception 'Expected parent split_count 3, got %', v_parent.split_count;
  end if;

  select count(*), coalesce(sum(number_of_parcels), 0)
  into v_child_count, v_child_qty
  from public.parcels
  where parent_parcel_id = v_parent.id;

  if v_child_count <> 3 or v_child_qty <> 4 then
    raise exception 'Expected 3 split children with total qty 4, got count %, qty %',
      v_child_count,
      v_child_qty;
  end if;

  select *
  into v_child_a
  from public.parcels
  where parent_parcel_id = v_parent.id
    and split_index = 'A';
  if not found then
    raise exception 'Expected child A row';
  end if;

  select *
  into v_child_b
  from public.parcels
  where parent_parcel_id = v_parent.id
    and split_index = 'B';
  if not found then
    raise exception 'Expected child B row';
  end if;

  select *
  into v_child_c
  from public.parcels
  where parent_parcel_id = v_parent.id
    and split_index = 'C';
  if not found then
    raise exception 'Expected child C row';
  end if;

  if v_child_a.tracking_id <> v_parent.tracking_id || '-A' then
    raise exception 'Expected child A tracking %, got %',
      v_parent.tracking_id || '-A', v_child_a.tracking_id;
  end if;

  if v_child_b.tracking_id <> v_parent.tracking_id || '-B' then
    raise exception 'Expected child B tracking %, got %',
      v_parent.tracking_id || '-B', v_child_b.tracking_id;
  end if;

  if v_child_c.tracking_id <> v_parent.tracking_id || '-C' then
    raise exception 'Expected child C tracking %, got %',
      v_parent.tracking_id || '-C', v_child_c.tracking_id;
  end if;

  select count(*) = count(distinct tracking_id)
  into v_child_tracking_ids_are_unique
  from public.parcels
  where parent_parcel_id = v_parent.id;

  if v_child_tracking_ids_are_unique is not true then
    raise exception 'Child tracking IDs are duplicated';
  end if;

  if v_child_a.number_of_parcels <> 2
      or v_child_b.number_of_parcels <> 1
      or v_child_c.number_of_parcels <> 1 then
    raise exception 'Expected child quantities 2, 1, 1, got %, %, %',
      v_child_a.number_of_parcels,
      v_child_b.number_of_parcels,
      v_child_c.number_of_parcels;
  end if;

  if v_child_a.total_charges <> 11111
      or v_child_b.total_charges <> 22222
      or v_child_c.total_charges <> 33333 then
    raise exception 'Manual child charges were not preserved: %, %, %',
      v_child_a.total_charges,
      v_child_b.total_charges,
      v_child_c.total_charges;
  end if;

  if v_child_a.cash_advance <> 101
      or v_child_b.cash_advance <> 202
      or v_child_c.cash_advance <> 303 then
    raise exception 'Manual child cash advances were not preserved: %, %, %',
      v_child_a.cash_advance,
      v_child_b.cash_advance,
      v_child_c.cash_advance;
  end if;

  select *
  into v_ledger
  from public.create_gate_ledger(v_context.driver_id, current_date);

  begin
    perform public.attach_parcel_to_gate_ledger(v_ledger.id, v_parent.tracking_id);
  exception
    when others then
      if sqlerrm like 'Split parent parcel cannot be attached%' then
        v_parent_attach_was_rejected := true;
      else
        raise;
      end if;
  end;

  if v_parent_attach_was_rejected is not true then
    raise exception 'Expected split parent ledger attach to be rejected';
  end if;

  select *
  into v_child_detail
  from public.attach_parcel_to_gate_ledger(v_ledger.id, v_child_a.tracking_id);

  if v_child_detail.parcel_id <> v_child_a.id then
    raise exception 'Expected child A to attach to ledger';
  end if;

  raise notice
    'OK progressive split voucher test: parent %, children %, %, %, qty %, %, %, parent attach rejected, child attach accepted',
    v_parent.tracking_id,
    v_child_a.tracking_id,
    v_child_b.tracking_id,
    v_child_c.tracking_id,
    v_child_a.number_of_parcels,
    v_child_b.number_of_parcels,
    v_child_c.number_of_parcels;
end;
$$;

rollback;
