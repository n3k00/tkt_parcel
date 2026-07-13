class GateDriver {
  const GateDriver({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicleNo,
  });

  final String id;
  final String name;
  final String phone;
  final String vehicleNo;

  factory GateDriver.fromMap(Map<String, dynamic> map) => GateDriver(
    id: map['id'] as String,
    name: map['name'] as String,
    phone: map['phone'] as String,
    vehicleNo: map['vehicle_no'] as String,
  );
}

class GateLedger {
  const GateLedger({
    required this.id,
    required this.driverId,
    required this.ledgerDate,
    required this.status,
  });

  final String id;
  final String driverId;
  final DateTime ledgerDate;
  final String status;

  bool get isSettled => status == 'settled';

  factory GateLedger.fromMap(Map<String, dynamic> map) => GateLedger(
    id: map['id'] as String,
    driverId: map['driver_id'] as String,
    ledgerDate: DateTime.parse(map['ledger_date'] as String),
    status: map['status'] as String,
  );
}

class GateLedgerEntry {
  const GateLedgerEntry({
    required this.id,
    required this.trackingId,
    required this.destinationTown,
  });

  final String id;
  final String trackingId;
  final String destinationTown;

  factory GateLedgerEntry.fromMap(Map<String, dynamic> map) => GateLedgerEntry(
    id: map['id'] as String,
    trackingId: map['tracking_id_snapshot'] as String,
    destinationTown: map['destination_town_snapshot'] as String,
  );
}

class GateIncoming {
  const GateIncoming({
    required this.id,
    required this.driverId,
    required this.incomingDate,
    required this.paymentStatus,
    required this.paymentAmount,
  });

  final String id;
  final String driverId;
  final DateTime incomingDate;
  final String paymentStatus;
  final double paymentAmount;

  bool get isPaid => paymentStatus == 'paid';

  factory GateIncoming.fromMap(Map<String, dynamic> map) => GateIncoming(
    id: map['id'] as String,
    driverId: map['driver_id'] as String,
    incomingDate: DateTime.parse(map['incoming_date'] as String),
    paymentStatus: map['driver_payment_status'] as String,
    paymentAmount: (map['driver_payment_amount'] as num).toDouble(),
  );
}

class GateIncomingEntry {
  const GateIncomingEntry({
    required this.id,
    required this.entryType,
    required this.receiverName,
    required this.receiverPhone,
    required this.destinationTown,
    required this.paymentStatus,
    required this.totalCharges,
    required this.cashAdvance,
    required this.claimed,
    this.trackingId,
    this.note,
    this.claimNote,
  });

  final String id;
  final String entryType;
  final String? trackingId;
  final String receiverName;
  final String receiverPhone;
  final String destinationTown;
  final String paymentStatus;
  final double totalCharges;
  final double cashAdvance;
  final bool claimed;
  final String? note;
  final String? claimNote;

  bool get isManual => entryType == 'manual';

  factory GateIncomingEntry.fromMap(Map<String, dynamic> map) =>
      GateIncomingEntry(
        id: map['id'] as String,
        entryType: map['entry_type'] as String,
        trackingId: map['tracking_id'] as String?,
        receiverName: map['receiver_name'] as String,
        receiverPhone: map['receiver_phone'] as String,
        destinationTown: map['destination_town'] as String,
        paymentStatus: map['payment_status'] as String,
        totalCharges: (map['total_charges'] as num).toDouble(),
        cashAdvance: (map['cash_advance'] as num).toDouble(),
        claimed: map['claimed'] as bool,
        note: map['note'] as String?,
        claimNote: map['claim_note'] as String?,
      );
}

class GateIncomingParcelPreview {
  const GateIncomingParcelPreview({
    required this.trackingId,
    required this.receiverName,
    required this.receiverPhone,
    required this.destinationTown,
    required this.paymentStatus,
    required this.totalCharges,
    required this.cashAdvance,
    this.note,
  });

  final String trackingId;
  final String receiverName;
  final String receiverPhone;
  final String destinationTown;
  final String paymentStatus;
  final double totalCharges;
  final double cashAdvance;
  final String? note;

  factory GateIncomingParcelPreview.fromMap(Map<String, dynamic> map) =>
      GateIncomingParcelPreview(
        trackingId: map['tracking_id'] as String,
        receiverName: map['receiver_name'] as String,
        receiverPhone: map['receiver_phone'] as String,
        destinationTown: map['destination_town'] as String,
        paymentStatus: map['payment_status'] as String,
        totalCharges: (map['total_charges'] as num).toDouble(),
        cashAdvance: (map['cash_advance'] as num).toDouble(),
        note: map['note'] as String?,
      );
}
