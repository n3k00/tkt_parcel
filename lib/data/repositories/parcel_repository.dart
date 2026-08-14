import 'package:drift/drift.dart';

import '../local/database/app_database.dart';
import '../mappers/parcel_mapper.dart';
import '../models/enums/parcel_status.dart';
import '../models/enums/sync_status.dart';
import '../models/parcel.dart';

class ParcelRepository {
  ParcelRepository(this._parcelsDao);

  final ParcelsDao _parcelsDao;

  Stream<List<ParcelModel>> watchParcels() {
    return _parcelsDao.watchAllParcels().map(
      (rows) => rows.map(ParcelMapper.toModel).toList(),
    );
  }

  Future<ParcelModel?> getParcel(int id) async {
    final row = await _parcelsDao.getParcelById(id);
    return row == null ? null : ParcelMapper.toModel(row);
  }

  Future<ParcelModel?> getParcelByTrackingId(String trackingId) async {
    final row = await _parcelsDao.getParcelByTrackingId(trackingId);
    return row == null ? null : ParcelMapper.toModel(row);
  }

  Future<List<ParcelModel>> getAllParcels() async {
    final rows = await _parcelsDao.getAllParcels();
    return rows.map(ParcelMapper.toModel).toList();
  }

  Future<List<ParcelModel>> searchParcels(String query) async {
    final rows = await _parcelsDao.searchParcels(query);
    return rows.map(ParcelMapper.toModel).toList();
  }

  Future<List<ParcelModel>> filterParcelsByStatus(ParcelStatus status) async {
    final rows = await _parcelsDao.filterParcelsByStatus(status);
    return rows.map(ParcelMapper.toModel).toList();
  }

  Future<List<ParcelModel>> filterParcelsByDate({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final rows = await _parcelsDao.filterParcelsByDate(
      startDate: startDate,
      endDate: endDate,
    );
    return rows.map(ParcelMapper.toModel).toList();
  }

  Future<int> countParcelsCreatedOn(DateTime date) async {
    final startDate = DateTime(date.year, date.month, date.day);
    final endDate = startDate
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    final rows = await _parcelsDao.filterParcelsByDate(
      startDate: startDate,
      endDate: endDate,
    );
    return rows.length;
  }

  Future<int> countParcelsCreatedOnForCounter(DateTime date, String cityCode) {
    final startDate = DateTime(date.year, date.month, date.day);
    final endDate = startDate
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    return _parcelsDao.countParcelsCreatedOnForCounter(
      startDate: startDate,
      endDate: endDate,
      cityCode: cityCode,
    );
  }

  Future<int> createParcel(
    ParcelModel parcel, {
    bool preserveSyncState = false,
  }) {
    final now = DateTime.now();
    final parcelToCreate = preserveSyncState
        ? parcel.copyWith(updatedAt: now)
        : parcel.copyWith(
            updatedAt: now,
            status: ParcelStatus.received,
            syncStatus: SyncStatus.pending,
            syncedAt: null,
            clearSyncedAt: true,
          );
    return _parcelsDao.insertParcel(
      ParcelsCompanion.insert(
        clientParcelId: Value(parcelToCreate.clientParcelId),
        trackingId: parcelToCreate.trackingId,
        createdAt: parcelToCreate.createdAt,
        deviceId: Value(parcelToCreate.deviceId),
        branchId: Value(parcelToCreate.branchId),
        fromTown: parcelToCreate.fromTown,
        toTown: parcelToCreate.toTown,
        cityCode: parcelToCreate.cityCode,
        accountCode: parcelToCreate.accountCode,
        senderName: parcelToCreate.senderName,
        senderPhone: parcelToCreate.senderPhone,
        receiverName: parcelToCreate.receiverName,
        receiverPhone: parcelToCreate.receiverPhone,
        parcelType: parcelToCreate.parcelType,
        numberOfParcels: parcelToCreate.numberOfParcels,
        totalCharges: parcelToCreate.totalCharges,
        paymentStatus: parcelToCreate.paymentStatus,
        cashAdvance: Value(parcelToCreate.cashAdvance),
        parcelImagePath: Value(parcelToCreate.parcelImagePath),
        remark: Value(parcelToCreate.remark),
        status: Value(parcelToCreate.status),
        syncStatus: Value(parcelToCreate.syncStatus),
        syncError: Value(parcelToCreate.syncError),
        lastSyncAttemptAt: Value(parcelToCreate.lastSyncAttemptAt),
        dispatchedAt: Value(parcelToCreate.dispatchedAt),
        syncedAt: Value(parcelToCreate.syncedAt),
        arrivedAt: Value(parcelToCreate.arrivedAt),
        claimedAt: Value(parcelToCreate.claimedAt),
        cancelledAt: Value(parcelToCreate.cancelledAt),
        dispatchId: Value(parcelToCreate.dispatchId),
        driverId: Value(parcelToCreate.driverId),
        driverName: Value(parcelToCreate.driverName),
        driverPhone: Value(parcelToCreate.driverPhone),
        dispatchedDate: Value(parcelToCreate.dispatchedDate),
        claimNote: Value(parcelToCreate.claimNote),
        parentParcelId: Value(parcelToCreate.parentParcelId),
        splitIndex: Value(parcelToCreate.splitIndex),
        splitCount: Value(parcelToCreate.splitCount),
        updatedAt: parcelToCreate.updatedAt,
      ),
    );
  }

  Future<bool> upsertSyncedParcel(ParcelModel parcel) async {
    final existing = await getParcelByTrackingId(parcel.trackingId);
    if (existing != null &&
        existing.syncStatus != SyncStatus.synced &&
        existing.clientParcelId != parcel.clientParcelId) {
      return false;
    }

    final syncedParcel = parcel.copyWith(
      id: existing?.id,
      accountCode: parcel.accountCode.isEmpty
          ? existing?.accountCode
          : parcel.accountCode,
      parcelImagePath: parcel.parcelImagePath ?? existing?.parcelImagePath,
      syncStatus: SyncStatus.synced,
      clearSyncError: true,
      lastSyncAttemptAt: DateTime.now(),
      syncedAt: parcel.syncedAt ?? DateTime.now(),
    );

    if (existing == null) {
      await createParcel(syncedParcel, preserveSyncState: true);
      return true;
    }

    await updateParcel(syncedParcel);
    return true;
  }

  Future<bool> updateParcel(ParcelModel parcel) {
    final parcelToUpdate = parcel.copyWith(updatedAt: DateTime.now());
    return _parcelsDao.updateParcel(
      ParcelsCompanion(
        id: Value(parcelToUpdate.id!),
        clientParcelId: Value(parcelToUpdate.clientParcelId),
        trackingId: Value(parcelToUpdate.trackingId),
        createdAt: Value(parcelToUpdate.createdAt),
        deviceId: Value(parcelToUpdate.deviceId),
        branchId: Value(parcelToUpdate.branchId),
        fromTown: Value(parcelToUpdate.fromTown),
        toTown: Value(parcelToUpdate.toTown),
        cityCode: Value(parcelToUpdate.cityCode),
        accountCode: Value(parcelToUpdate.accountCode),
        senderName: Value(parcelToUpdate.senderName),
        senderPhone: Value(parcelToUpdate.senderPhone),
        receiverName: Value(parcelToUpdate.receiverName),
        receiverPhone: Value(parcelToUpdate.receiverPhone),
        parcelType: Value(parcelToUpdate.parcelType),
        numberOfParcels: Value(parcelToUpdate.numberOfParcels),
        totalCharges: Value(parcelToUpdate.totalCharges),
        paymentStatus: Value(parcelToUpdate.paymentStatus),
        cashAdvance: Value(parcelToUpdate.cashAdvance),
        parcelImagePath: Value(parcelToUpdate.parcelImagePath),
        remark: Value(parcelToUpdate.remark),
        status: Value(parcelToUpdate.status),
        syncStatus: Value(parcelToUpdate.syncStatus),
        syncError: Value(parcelToUpdate.syncError),
        lastSyncAttemptAt: Value(parcelToUpdate.lastSyncAttemptAt),
        dispatchedAt: Value(parcelToUpdate.dispatchedAt),
        syncedAt: Value(parcelToUpdate.syncedAt),
        arrivedAt: Value(parcelToUpdate.arrivedAt),
        claimedAt: Value(parcelToUpdate.claimedAt),
        cancelledAt: Value(parcelToUpdate.cancelledAt),
        dispatchId: Value(parcelToUpdate.dispatchId),
        driverId: Value(parcelToUpdate.driverId),
        driverName: Value(parcelToUpdate.driverName),
        driverPhone: Value(parcelToUpdate.driverPhone),
        dispatchedDate: Value(parcelToUpdate.dispatchedDate),
        claimNote: Value(parcelToUpdate.claimNote),
        parentParcelId: Value(parcelToUpdate.parentParcelId),
        splitIndex: Value(parcelToUpdate.splitIndex),
        splitCount: Value(parcelToUpdate.splitCount),
        updatedAt: Value(parcelToUpdate.updatedAt),
      ),
    );
  }

  Future<int> deleteParcel(int id) {
    return _parcelsDao.deleteParcelById(id);
  }
}
