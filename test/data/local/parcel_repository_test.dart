import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkt_parcel/data/local/database/app_database.dart';
import 'package:tkt_parcel/data/models/enums/payment_status.dart';
import 'package:tkt_parcel/data/models/enums/parcel_status.dart';
import 'package:tkt_parcel/data/models/parcel.dart';
import 'package:tkt_parcel/data/repositories/parcel_repository.dart';

void main() {
  late AppDatabase database;
  late ParcelRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ParcelRepository(database.parcelsDao);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates a parcel locally with offline-safe defaults', () async {
    final id = await repository.createParcel(
      _buildParcel(trackingId: 'TGI-A1-250317-0001'),
    );
    final saved = await repository.getParcel(id);

    expect(saved, isNotNull);
    expect(saved!.trackingId, 'TGI-A1-250317-0001');
    expect(saved.status, ParcelStatus.received);
    expect(saved.syncStatus.name, 'pending');
    expect(saved.syncedAt, isNull);
    expect(saved.cashAdvance, 0);
    expect(saved.parcelImagePath, 'C:/parcel-images/sample.jpg');
  });

  test('updates a parcel and refreshes updatedAt', () async {
    final id = await repository.createParcel(
      _buildParcel(trackingId: 'TGI-A1-250317-0002'),
    );
    final saved = await repository.getParcel(id);
    final originalUpdatedAt = saved!.updatedAt;

    await Future<void>.delayed(const Duration(seconds: 1));

    final updated = saved.copyWith(
      id: id,
      receiverName: 'Updated Receiver',
      totalCharges: 9500,
      status: ParcelStatus.arrived,
    );
    await repository.updateParcel(updated);
    final reloaded = await repository.getParcel(id);

    expect(reloaded, isNotNull);
    expect(reloaded!.receiverName, 'Updated Receiver');
    expect(reloaded.totalCharges, 9500);
    expect(reloaded.status, ParcelStatus.arrived);
    expect(reloaded.updatedAt.isAfter(originalUpdatedAt), isTrue);
  });

  test('fetches a parcel by tracking ID', () async {
    await repository.createParcel(
      _buildParcel(trackingId: 'TGI-A1-250317-0003'),
    );

    final saved = await repository.getParcelByTrackingId('TGI-A1-250317-0003');

    expect(saved, isNotNull);
    expect(saved!.receiverName, 'Ma Su');
  });

  test('persists sync and dispatch metadata fields', () async {
    final dispatchedAt = DateTime(2025, 3, 17, 12, 30);
    final lastSyncAttemptAt = DateTime(2025, 3, 17, 12, 45);
    final id = await repository.createParcel(
      _buildParcel(
        trackingId: 'TGI-A1-250317-0004',
        clientParcelId: 'client-parcel-001',
        deviceId: 'device-001',
        branchId: 'branch-tgi',
      ).copyWith(
        syncError: 'Network unavailable',
        lastSyncAttemptAt: lastSyncAttemptAt,
        dispatchedAt: dispatchedAt,
        dispatchId: 'dispatch-001',
        driverId: 'driver-001',
        driverName: 'Ko Driver',
        driverPhone: '09111222333',
        dispatchedDate: DateTime(2025, 3, 17),
        claimNote: 'Waiting for receiver.',
      ),
    );

    final saved = await repository.getParcel(id);

    expect(saved, isNotNull);
    expect(saved!.clientParcelId, 'client-parcel-001');
    expect(saved.deviceId, 'device-001');
    expect(saved.branchId, 'branch-tgi');
    expect(saved.syncError, 'Network unavailable');
    expect(saved.lastSyncAttemptAt, lastSyncAttemptAt);
    expect(saved.dispatchedAt, dispatchedAt);
    expect(saved.dispatchId, 'dispatch-001');
    expect(saved.driverId, 'driver-001');
    expect(saved.driverName, 'Ko Driver');
    expect(saved.driverPhone, '09111222333');
    expect(saved.dispatchedDate, DateTime(2025, 3, 17));
    expect(saved.claimNote, 'Waiting for receiver.');
  });

  test('persists split parcel metadata fields', () async {
    final id = await repository.createParcel(
      _buildParcel(trackingId: 'TGI-260814-0001-A').copyWith(
        status: ParcelStatus.split,
        parentParcelId: 'parent-server-parcel-id',
        splitIndex: 'A',
        splitCount: 2,
      ),
      preserveSyncState: true,
    );

    final saved = await repository.getParcel(id);

    expect(saved, isNotNull);
    expect(saved!.status, ParcelStatus.split);
    expect(saved.parentParcelId, 'parent-server-parcel-id');
    expect(saved.splitIndex, 'A');
    expect(saved.splitCount, 2);
  });

  test('persists partially split parent status', () async {
    final id = await repository.createParcel(
      _buildParcel(
        trackingId: 'TGI-260814-0001',
      ).copyWith(status: ParcelStatus.partiallySplit, splitCount: 1),
      preserveSyncState: true,
    );

    final saved = await repository.getParcel(id);

    expect(saved, isNotNull);
    expect(saved!.status, ParcelStatus.partiallySplit);
    expect(saved.splitCount, 1);
  });

  test('updates lifecycle timestamps and claim note metadata', () async {
    final id = await repository.createParcel(
      _buildParcel(trackingId: 'TGI-A1-250317-0005'),
    );
    final saved = await repository.getParcel(id);
    final claimedAt = DateTime(2025, 3, 18, 10);
    final cancelledAt = DateTime(2025, 3, 19, 11);

    await repository.updateParcel(
      saved!.copyWith(
        status: ParcelStatus.cancelled,
        claimedAt: claimedAt,
        cancelledAt: cancelledAt,
        claimNote: 'Receiver came with ID card.',
      ),
    );

    final reloaded = await repository.getParcel(id);

    expect(reloaded, isNotNull);
    expect(reloaded!.status, ParcelStatus.cancelled);
    expect(reloaded.claimedAt, claimedAt);
    expect(reloaded.cancelledAt, cancelledAt);
    expect(reloaded.claimNote, 'Receiver came with ID card.');
  });

  test('counts parcels by city code and date for tracking IDs', () async {
    await repository.createParcel(
      _buildParcel(
        trackingId: 'TGI-A1-250317-0001',
        cityCode: 'TGI',
        accountCode: 'A1',
      ),
    );
    await repository.createParcel(
      _buildParcel(
        trackingId: 'TGI-A1-250317-0002',
        cityCode: 'TGI',
        accountCode: 'A1',
      ),
    );
    await repository.createParcel(
      _buildParcel(
        trackingId: 'LSO-A1-250317-0001',
        cityCode: 'LSO',
        accountCode: 'A1',
      ),
    );
    await repository.createParcel(
      _buildParcel(
        trackingId: 'TGI-B2-250317-0001',
        cityCode: 'TGI',
        accountCode: 'B2',
      ),
    );
    await repository.createParcel(
      _buildParcel(
        trackingId: 'TGI-A1-250318-0001',
        cityCode: 'TGI',
        accountCode: 'A1',
        now: DateTime(2025, 3, 18, 9),
      ),
    );

    final count = await repository.countParcelsCreatedOnForCounter(
      DateTime(2025, 3, 17),
      'TGI',
    );

    expect(count, 3);
  });
}

ParcelModel _buildParcel({
  required String trackingId,
  String? clientParcelId,
  String? deviceId,
  String? branchId,
  String cityCode = 'TGI',
  String accountCode = 'A1',
  DateTime? now,
}) {
  return ParcelModel.create(
    clientParcelId: clientParcelId,
    trackingId: trackingId,
    deviceId: deviceId,
    branchId: branchId,
    fromTown: 'Taunggyi',
    toTown: 'Kalaw',
    cityCode: cityCode,
    accountCode: accountCode,
    senderName: 'Ko Aung',
    senderPhone: '0912345678',
    receiverName: 'Ma Su',
    receiverPhone: '0998765432',
    parcelType: 'Document',
    numberOfParcels: 1,
    totalCharges: 7000,
    paymentStatus: PaymentStatus.paid,
    parcelImagePath: 'C:/parcel-images/sample.jpg',
    remark: 'Handle carefully',
    now: now ?? DateTime(2025, 3, 17, 9, 0),
  );
}
