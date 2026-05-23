part of '../app_database.dart';

class Parcels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientParcelId =>
      text().named('client_parcel_id').nullable()();
  TextColumn get trackingId => text().named('tracking_id')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  TextColumn get deviceId => text().named('device_id').nullable()();
  TextColumn get branchId => text().named('branch_id').nullable()();
  TextColumn get fromTown => text().named('from_town')();
  TextColumn get toTown => text().named('to_town')();
  TextColumn get cityCode => text().named('city_code')();
  TextColumn get accountCode => text().named('account_code')();
  TextColumn get senderName => text().named('sender_name')();
  TextColumn get senderPhone => text().named('sender_phone')();
  TextColumn get receiverName => text().named('receiver_name')();
  TextColumn get receiverPhone => text().named('receiver_phone')();
  TextColumn get parcelType => text().named('parcel_type')();
  IntColumn get numberOfParcels => integer().named('number_of_parcels')();
  RealColumn get totalCharges => real().named('total_charges')();
  TextColumn get paymentStatus =>
      textEnum<PaymentStatus>().named('payment_status')();
  RealColumn get cashAdvance =>
      real().named('cash_advance').withDefault(const Constant(0))();
  TextColumn get parcelImagePath =>
      text().named('parcel_image_path').nullable()();
  TextColumn get remark => text().nullable()();
  TextColumn get status =>
      textEnum<ParcelStatus>().withDefault(const Constant('received'))();
  TextColumn get syncStatus => textEnum<SyncStatus>()
      .named('sync_status')
      .withDefault(const Constant('pending'))();
  TextColumn get syncError => text().named('sync_error').nullable()();
  DateTimeColumn get lastSyncAttemptAt =>
      dateTime().named('last_sync_attempt_at').nullable()();
  DateTimeColumn get dispatchedAt =>
      dateTime().named('dispatched_at').nullable()();
  DateTimeColumn get syncedAt => dateTime().named('synced_at').nullable()();
  DateTimeColumn get arrivedAt => dateTime().named('arrived_at').nullable()();
  DateTimeColumn get claimedAt => dateTime().named('claimed_at').nullable()();
  DateTimeColumn get cancelledAt =>
      dateTime().named('cancelled_at').nullable()();
  TextColumn get dispatchId => text().named('dispatch_id').nullable()();
  TextColumn get driverId => text().named('driver_id').nullable()();
  TextColumn get driverName => text().named('driver_name').nullable()();
  TextColumn get driverPhone => text().named('driver_phone').nullable()();
  DateTimeColumn get dispatchedDate =>
      dateTime().named('dispatched_date').nullable()();
  TextColumn get claimNote => text().named('claim_note').nullable()();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  List<Set<Column>> get uniqueKeys => [
    {trackingId},
  ];

  @override
  List<String> get customConstraints => const [
    'CHECK (number_of_parcels > 0)',
    'CHECK (total_charges >= 0)',
    'CHECK (cash_advance >= 0)',
  ];
}
