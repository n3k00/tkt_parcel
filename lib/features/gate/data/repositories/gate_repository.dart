import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/gate_models.dart';

class GateRepository {
  const GateRepository(this._client);

  final SupabaseClient _client;

  Future<List<GateDriver>> fetchDrivers() async {
    final rows = await _client
        .from('drivers')
        .select('id, name, phone, vehicle_no')
        .eq('active', true)
        .order('name');
    return rows.map(GateDriver.fromMap).toList();
  }

  Future<List<GateLedger>> fetchLedgers() async {
    final rows = await _client
        .from('gate_ledger_mains')
        .select()
        .order('ledger_date', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(GateLedger.fromMap).toList();
  }

  Future<List<GateLedgerEntry>> fetchLedgerEntries(String ledgerId) async {
    final rows = await _client
        .from('gate_ledger_entries')
        .select()
        .eq('ledger_id', ledgerId)
        .isFilter('removed_at', null)
        .order('attached_at');
    return rows.map(GateLedgerEntry.fromMap).toList();
  }

  Future<void> createLedger(String driverId) => _rpc('create_gate_ledger', {
    'p_driver_id': driverId,
    'p_ledger_date': _today(),
  });

  Future<void> attachLedgerParcel(String ledgerId, String trackingId) => _rpc(
    'attach_parcel_to_gate_ledger',
    {'p_ledger_id': ledgerId, 'p_tracking_id': trackingId.trim()},
  );

  Future<void> removeLedgerEntry(String entryId) =>
      _rpc('remove_gate_ledger_entry', {'p_entry_id': entryId});

  Future<void> settleLedger(String ledgerId) =>
      _rpc('settle_gate_ledger', {'p_ledger_id': ledgerId});

  Future<List<GateIncoming>> fetchIncomingLists() async {
    final rows = await _client
        .from('gate_incoming_mains')
        .select()
        .order('incoming_date', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(GateIncoming.fromMap).toList();
  }

  Future<List<GateIncomingEntry>> fetchIncomingEntries(
    String incomingId,
  ) async {
    final rows = await _client
        .from('gate_incoming_entries')
        .select()
        .eq('incoming_id', incomingId)
        .isFilter('removed_at', null)
        .order('attached_at');
    return rows.map(GateIncomingEntry.fromMap).toList();
  }

  Future<void> createIncoming(String driverId) => _rpc('create_gate_incoming', {
    'p_driver_id': driverId,
    'p_incoming_date': _today(),
  });

  Future<void> attachExistingIncoming(String incomingId, String trackingId) =>
      _rpc('attach_existing_gate_incoming_parcel', {
        'p_incoming_id': incomingId,
        'p_tracking_id': trackingId.trim(),
      });

  Future<GateIncomingParcelPreview> lookupIncomingParcel(
    String incomingId,
    String trackingId,
  ) async {
    final row = await _client.rpc(
      'lookup_gate_incoming_parcel',
      params: {'p_incoming_id': incomingId, 'p_tracking_id': trackingId.trim()},
    );
    return GateIncomingParcelPreview.fromMap(
      Map<String, dynamic>.from(row as Map),
    );
  }

  Future<void> addManualIncoming({
    required String incomingId,
    required String receiverName,
    required String receiverPhone,
    required String destinationTown,
    required String paymentStatus,
    required double totalCharges,
    required double cashAdvance,
    required String note,
  }) => _rpc('add_manual_gate_incoming_parcel', {
    'p_incoming_id': incomingId,
    'p_receiver_name': receiverName.trim(),
    'p_receiver_phone': receiverPhone.trim(),
    'p_destination_town': destinationTown.trim(),
    'p_payment_status': paymentStatus,
    'p_total_charges': totalCharges,
    'p_cash_advance': cashAdvance,
    'p_note': note.trim(),
  });

  Future<void> removeIncomingEntry(String entryId) =>
      _rpc('remove_gate_incoming_entry', {'p_entry_id': entryId});

  Future<void> updateManualIncoming({
    required String entryId,
    required String receiverName,
    required String receiverPhone,
    required String destinationTown,
    required String paymentStatus,
    required double totalCharges,
    required double cashAdvance,
    required String note,
  }) => _rpc('update_manual_gate_incoming_parcel', {
    'p_entry_id': entryId,
    'p_receiver_name': receiverName.trim(),
    'p_receiver_phone': receiverPhone.trim(),
    'p_destination_town': destinationTown.trim(),
    'p_payment_status': paymentStatus,
    'p_total_charges': totalCharges,
    'p_cash_advance': cashAdvance,
    'p_note': note.trim(),
  });

  Future<void> markIncomingPaid({
    required String incomingId,
    required double amount,
    required String note,
  }) => _rpc('mark_gate_incoming_driver_paid', {
    'p_incoming_id': incomingId,
    'p_amount': amount,
    'p_note': note.trim(),
  });

  Future<void> claimIncomingEntry({
    required String entryId,
    required String claimNote,
    String? paymentStatus,
  }) => _rpc('mark_gate_incoming_entry_claimed', {
    'p_entry_id': entryId,
    'p_claim_note': claimNote.trim(),
    'p_payment_status': paymentStatus,
  });

  Future<void> _rpc(String name, Map<String, dynamic> params) async {
    await _client.rpc(name, params: params);
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
