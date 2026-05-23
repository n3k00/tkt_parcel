import 'enums/parcel_status.dart';
import 'enums/payment_status.dart';
import 'enums/sync_status.dart';

class ParcelModel {
  const ParcelModel({
    this.id,
    this.clientParcelId,
    required this.trackingId,
    required this.createdAt,
    this.deviceId,
    this.branchId,
    required this.fromTown,
    required this.toTown,
    required this.cityCode,
    required this.accountCode,
    required this.senderName,
    required this.senderPhone,
    required this.receiverName,
    required this.receiverPhone,
    required this.parcelType,
    required this.numberOfParcels,
    required this.totalCharges,
    required this.paymentStatus,
    this.cashAdvance = 0,
    this.parcelImagePath,
    this.remark,
    this.status = ParcelStatus.received,
    this.syncStatus = SyncStatus.pending,
    this.syncError,
    this.lastSyncAttemptAt,
    this.dispatchedAt,
    this.syncedAt,
    this.arrivedAt,
    this.claimedAt,
    this.cancelledAt,
    this.dispatchId,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.dispatchedDate,
    this.claimNote,
    required this.updatedAt,
  });

  factory ParcelModel.create({
    String? clientParcelId,
    required String trackingId,
    String? deviceId,
    String? branchId,
    required String fromTown,
    required String toTown,
    required String cityCode,
    required String accountCode,
    required String senderName,
    required String senderPhone,
    required String receiverName,
    required String receiverPhone,
    required String parcelType,
    required int numberOfParcels,
    required double totalCharges,
    required PaymentStatus paymentStatus,
    double cashAdvance = 0,
    String? parcelImagePath,
    String? remark,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return ParcelModel(
      clientParcelId: clientParcelId,
      trackingId: trackingId,
      createdAt: timestamp,
      deviceId: deviceId,
      branchId: branchId,
      fromTown: fromTown,
      toTown: toTown,
      cityCode: cityCode,
      accountCode: accountCode,
      senderName: senderName,
      senderPhone: senderPhone,
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      parcelType: parcelType,
      numberOfParcels: numberOfParcels,
      totalCharges: totalCharges,
      paymentStatus: paymentStatus,
      cashAdvance: cashAdvance,
      parcelImagePath: parcelImagePath,
      remark: remark,
      updatedAt: timestamp,
    );
  }

  final int? id;
  final String? clientParcelId;
  final String trackingId;
  final DateTime createdAt;
  final String? deviceId;
  final String? branchId;
  final String fromTown;
  final String toTown;
  final String cityCode;
  final String accountCode;
  final String senderName;
  final String senderPhone;
  final String receiverName;
  final String receiverPhone;
  final String parcelType;
  final int numberOfParcels;
  final double totalCharges;
  final PaymentStatus paymentStatus;
  final double cashAdvance;
  final String? parcelImagePath;
  final String? remark;
  final ParcelStatus status;
  final SyncStatus syncStatus;
  final String? syncError;
  final DateTime? lastSyncAttemptAt;
  final DateTime? dispatchedAt;
  final DateTime? syncedAt;
  final DateTime? arrivedAt;
  final DateTime? claimedAt;
  final DateTime? cancelledAt;
  final String? dispatchId;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final DateTime? dispatchedDate;
  final String? claimNote;
  final DateTime updatedAt;

  ParcelModel copyWith({
    int? id,
    String? clientParcelId,
    bool clearClientParcelId = false,
    String? trackingId,
    DateTime? createdAt,
    String? deviceId,
    bool clearDeviceId = false,
    String? branchId,
    bool clearBranchId = false,
    String? fromTown,
    String? toTown,
    String? cityCode,
    String? accountCode,
    String? senderName,
    String? senderPhone,
    String? receiverName,
    String? receiverPhone,
    String? parcelType,
    int? numberOfParcels,
    double? totalCharges,
    PaymentStatus? paymentStatus,
    double? cashAdvance,
    String? parcelImagePath,
    bool clearParcelImagePath = false,
    String? remark,
    bool clearRemark = false,
    ParcelStatus? status,
    SyncStatus? syncStatus,
    String? syncError,
    bool clearSyncError = false,
    DateTime? lastSyncAttemptAt,
    bool clearLastSyncAttemptAt = false,
    DateTime? dispatchedAt,
    bool clearDispatchedAt = false,
    DateTime? syncedAt,
    bool clearSyncedAt = false,
    DateTime? arrivedAt,
    bool clearArrivedAt = false,
    DateTime? claimedAt,
    bool clearClaimedAt = false,
    DateTime? cancelledAt,
    bool clearCancelledAt = false,
    String? dispatchId,
    bool clearDispatchId = false,
    String? driverId,
    bool clearDriverId = false,
    String? driverName,
    bool clearDriverName = false,
    String? driverPhone,
    bool clearDriverPhone = false,
    DateTime? dispatchedDate,
    bool clearDispatchedDate = false,
    String? claimNote,
    bool clearClaimNote = false,
    DateTime? updatedAt,
  }) {
    return ParcelModel(
      id: id ?? this.id,
      clientParcelId: clearClientParcelId
          ? null
          : clientParcelId ?? this.clientParcelId,
      trackingId: trackingId ?? this.trackingId,
      createdAt: createdAt ?? this.createdAt,
      deviceId: clearDeviceId ? null : deviceId ?? this.deviceId,
      branchId: clearBranchId ? null : branchId ?? this.branchId,
      fromTown: fromTown ?? this.fromTown,
      toTown: toTown ?? this.toTown,
      cityCode: cityCode ?? this.cityCode,
      accountCode: accountCode ?? this.accountCode,
      senderName: senderName ?? this.senderName,
      senderPhone: senderPhone ?? this.senderPhone,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      parcelType: parcelType ?? this.parcelType,
      numberOfParcels: numberOfParcels ?? this.numberOfParcels,
      totalCharges: totalCharges ?? this.totalCharges,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      cashAdvance: cashAdvance ?? this.cashAdvance,
      parcelImagePath: clearParcelImagePath
          ? null
          : parcelImagePath ?? this.parcelImagePath,
      remark: clearRemark ? null : remark ?? this.remark,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: clearSyncError ? null : syncError ?? this.syncError,
      lastSyncAttemptAt: clearLastSyncAttemptAt
          ? null
          : lastSyncAttemptAt ?? this.lastSyncAttemptAt,
      dispatchedAt: clearDispatchedAt
          ? null
          : dispatchedAt ?? this.dispatchedAt,
      syncedAt: clearSyncedAt ? null : syncedAt ?? this.syncedAt,
      arrivedAt: clearArrivedAt ? null : arrivedAt ?? this.arrivedAt,
      claimedAt: clearClaimedAt ? null : claimedAt ?? this.claimedAt,
      cancelledAt: clearCancelledAt ? null : cancelledAt ?? this.cancelledAt,
      dispatchId: clearDispatchId ? null : dispatchId ?? this.dispatchId,
      driverId: clearDriverId ? null : driverId ?? this.driverId,
      driverName: clearDriverName ? null : driverName ?? this.driverName,
      driverPhone: clearDriverPhone ? null : driverPhone ?? this.driverPhone,
      dispatchedDate: clearDispatchedDate
          ? null
          : dispatchedDate ?? this.dispatchedDate,
      claimNote: clearClaimNote ? null : claimNote ?? this.claimNote,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientParcelId': clientParcelId,
      'trackingId': trackingId,
      'createdAt': createdAt.toIso8601String(),
      'deviceId': deviceId,
      'branchId': branchId,
      'fromTown': fromTown,
      'toTown': toTown,
      'cityCode': cityCode,
      'accountCode': accountCode,
      'senderName': senderName,
      'senderPhone': senderPhone,
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'parcelType': parcelType,
      'numberOfParcels': numberOfParcels,
      'totalCharges': totalCharges,
      'paymentStatus': paymentStatus.value,
      'cashAdvance': cashAdvance,
      'parcelImagePath': parcelImagePath,
      'remark': remark,
      'status': status.value,
      'syncStatus': syncStatus.value,
      'syncError': syncError,
      'lastSyncAttemptAt': lastSyncAttemptAt?.toIso8601String(),
      'dispatchedAt': dispatchedAt?.toIso8601String(),
      'syncedAt': syncedAt?.toIso8601String(),
      'arrivedAt': arrivedAt?.toIso8601String(),
      'claimedAt': claimedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'dispatchId': dispatchId,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'dispatchedDate': dispatchedDate?.toIso8601String(),
      'claimNote': claimNote,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ParcelModel.fromMap(Map<String, dynamic> map) {
    return ParcelModel(
      id: map['id'] as int?,
      clientParcelId: map['clientParcelId'] as String?,
      trackingId: map['trackingId'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      deviceId: map['deviceId'] as String?,
      branchId: map['branchId'] as String?,
      fromTown: map['fromTown'] as String,
      toTown: map['toTown'] as String,
      cityCode: map['cityCode'] as String,
      accountCode: map['accountCode'] as String,
      senderName: map['senderName'] as String,
      senderPhone: map['senderPhone'] as String,
      receiverName: map['receiverName'] as String,
      receiverPhone: map['receiverPhone'] as String,
      parcelType: map['parcelType'] as String,
      numberOfParcels: (map['numberOfParcels'] as num).toInt(),
      totalCharges: (map['totalCharges'] as num).toDouble(),
      paymentStatus: PaymentStatus.fromValue(map['paymentStatus'] as String),
      cashAdvance: ((map['cashAdvance'] as num?) ?? 0).toDouble(),
      parcelImagePath: map['parcelImagePath'] as String?,
      remark: map['remark'] as String?,
      status: ParcelStatus.fromValue(map['status'] as String),
      syncStatus: SyncStatus.fromValue(map['syncStatus'] as String),
      syncError: map['syncError'] as String?,
      lastSyncAttemptAt: _readDateTime(map['lastSyncAttemptAt']),
      dispatchedAt: _readDateTime(map['dispatchedAt']),
      syncedAt: _readDateTime(map['syncedAt']),
      arrivedAt: _readDateTime(map['arrivedAt']),
      claimedAt: _readDateTime(map['claimedAt']),
      cancelledAt: _readDateTime(map['cancelledAt']),
      dispatchId: map['dispatchId'] as String?,
      driverId: map['driverId'] as String?,
      driverName: map['driverName'] as String?,
      driverPhone: map['driverPhone'] as String?,
      dispatchedDate: _readDateTime(map['dispatchedDate']),
      claimNote: map['claimNote'] as String?,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.parse(value as String);
  }
}
