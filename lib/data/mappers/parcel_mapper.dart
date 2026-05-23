import '../models/parcel.dart';
import '../local/database/app_database.dart';

class ParcelMapper {
  const ParcelMapper._();

  static ParcelModel toModel(Parcel row) {
    return ParcelModel(
      id: row.id,
      clientParcelId: row.clientParcelId,
      trackingId: row.trackingId,
      createdAt: row.createdAt,
      deviceId: row.deviceId,
      branchId: row.branchId,
      fromTown: row.fromTown,
      toTown: row.toTown,
      cityCode: row.cityCode,
      accountCode: row.accountCode,
      senderName: row.senderName,
      senderPhone: row.senderPhone,
      receiverName: row.receiverName,
      receiverPhone: row.receiverPhone,
      parcelType: row.parcelType,
      numberOfParcels: row.numberOfParcels,
      totalCharges: row.totalCharges,
      paymentStatus: row.paymentStatus,
      cashAdvance: row.cashAdvance,
      parcelImagePath: row.parcelImagePath,
      remark: row.remark,
      status: row.status,
      syncStatus: row.syncStatus,
      syncError: row.syncError,
      lastSyncAttemptAt: row.lastSyncAttemptAt,
      dispatchedAt: row.dispatchedAt,
      syncedAt: row.syncedAt,
      arrivedAt: row.arrivedAt,
      claimedAt: row.claimedAt,
      cancelledAt: row.cancelledAt,
      dispatchId: row.dispatchId,
      driverId: row.driverId,
      driverName: row.driverName,
      driverPhone: row.driverPhone,
      dispatchedDate: row.dispatchedDate,
      claimNote: row.claimNote,
      updatedAt: row.updatedAt,
    );
  }
}
