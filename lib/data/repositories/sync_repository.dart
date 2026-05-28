import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/preferences/app_preferences.dart';
import '../models/enums/parcel_status.dart';
import '../models/enums/payment_status.dart';
import '../models/enums/sync_status.dart';
import '../models/parcel.dart';
import 'parcel_repository.dart';

class SyncRepository {
  const SyncRepository(this._client, this._parcelRepository, this._preferences);

  final SupabaseClient _client;
  final ParcelRepository _parcelRepository;
  final AppPreferences _preferences;

  Future<String> syncNow() async {
    final count = await pullParcelsFromServer();
    return 'Updated $count parcel${count == 1 ? '' : 's'} from server.';
  }

  Future<int> pullParcelsFromServer() async {
    if (_client.auth.currentSession == null) {
      throw StateError('Please sign in before refreshing parcels.');
    }

    final lastSyncedAt = _preferences.getParcelPullLastSyncedAt();
    final response = lastSyncedAt == null
        ? await _client
              .from('parcels')
              .select()
              .order('updated_at', ascending: true)
        : await _client
              .from('parcels')
              .select()
              .gt('updated_at', lastSyncedAt.toUtc().toIso8601String())
              .order('updated_at', ascending: true);

    var updatedCount = 0;
    DateTime? maxServerUpdatedAt;
    final syncedAt = DateTime.now();
    for (final item in response) {
      final parcel = _parcelFromServerRow(item, syncedAt: syncedAt);
      final didUpsert = await _parcelRepository.upsertSyncedParcel(parcel);
      if (didUpsert) {
        updatedCount++;
      }
      if (maxServerUpdatedAt == null ||
          parcel.updatedAt.isAfter(maxServerUpdatedAt)) {
        maxServerUpdatedAt = parcel.updatedAt;
      }
    }

    if (maxServerUpdatedAt != null) {
      await _preferences.setParcelPullLastSyncedAt(maxServerUpdatedAt);
    }

    return updatedCount;
  }

  Future<ParcelModel> createParcelWithServerCounter(ParcelModel parcel) async {
    if (_client.auth.currentSession == null) {
      throw StateError('Please sign in before printing official vouchers.');
    }

    final clientParcelId = parcel.clientParcelId;
    if (clientParcelId == null || clientParcelId.isEmpty) {
      throw StateError('Missing client parcel ID.');
    }

    final branchId = parcel.branchId;
    if (branchId == null || branchId.isEmpty) {
      throw StateError('Missing branch ID.');
    }

    final now = DateTime.now();
    final response = await _client.rpc(
      'create_parcel_with_counter',
      params: {
        'p_client_parcel_id': clientParcelId,
        'p_device_id': null,
        'p_branch_id': branchId,
        'p_from_town': parcel.fromTown,
        'p_to_town': parcel.toTown,
        'p_city_code': parcel.cityCode,
        'p_sender_name': parcel.senderName,
        'p_sender_phone': parcel.senderPhone,
        'p_receiver_name': parcel.receiverName,
        'p_receiver_phone': parcel.receiverPhone,
        'p_parcel_type': parcel.parcelType,
        'p_number_of_parcels': parcel.numberOfParcels,
        'p_total_charges': parcel.totalCharges,
        'p_payment_status': parcel.paymentStatus.value,
        'p_cash_advance': parcel.cashAdvance,
        'p_remark': parcel.remark,
        'p_created_at': parcel.createdAt.toUtc().toIso8601String(),
      },
    );

    final row = _readRpcRow(response);
    final trackingId = row['tracking_id'] as String?;
    if (trackingId == null || trackingId.isEmpty) {
      throw StateError('Server did not return a tracking ID.');
    }

    return parcel.copyWith(
      clientParcelId: row['client_parcel_id'] as String? ?? clientParcelId,
      trackingId: trackingId,
      syncStatus: SyncStatus.synced,
      clearSyncError: true,
      lastSyncAttemptAt: now,
      syncedAt: _readDateTime(row['synced_at']) ?? now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> _readRpcRow(Object? response) {
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    throw StateError('Server did not return parcel data.');
  }

  DateTime? _readDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  ParcelModel _parcelFromServerRow(
    Map<String, dynamic> row, {
    required DateTime syncedAt,
  }) {
    return ParcelModel(
      clientParcelId: row['client_parcel_id'] as String?,
      trackingId: _readRequiredString(row, 'tracking_id'),
      createdAt: _readRequiredDateTime(row, 'created_at'),
      deviceId: row['device_id'] as String?,
      branchId: row['branch_id'] as String?,
      fromTown: _readRequiredString(row, 'from_town'),
      toTown: _readRequiredString(row, 'to_town'),
      cityCode: _readRequiredString(row, 'city_code'),
      accountCode: (row['account_code'] as String?) ?? '',
      senderName: _readRequiredString(row, 'sender_name'),
      senderPhone: _readRequiredString(row, 'sender_phone'),
      receiverName: _readRequiredString(row, 'receiver_name'),
      receiverPhone: _readRequiredString(row, 'receiver_phone'),
      parcelType: _readRequiredString(row, 'parcel_type'),
      numberOfParcels: _readRequiredInt(row, 'number_of_parcels'),
      totalCharges: _readRequiredDouble(row, 'total_charges'),
      paymentStatus: PaymentStatus.fromValue(
        _readRequiredString(row, 'payment_status'),
      ),
      cashAdvance: _readDouble(row['cash_advance']) ?? 0,
      remark: row['remark'] as String?,
      status: ParcelStatus.fromValue(
        (row['status'] as String?) ?? ParcelStatus.received.value,
      ),
      syncStatus: SyncStatus.synced,
      lastSyncAttemptAt: syncedAt,
      dispatchedAt: _readDateTime(row['dispatched_at']),
      syncedAt: syncedAt,
      arrivedAt: _readDateTime(row['arrived_at']),
      claimedAt: _readDateTime(row['claimed_at']),
      cancelledAt: _readDateTime(row['cancelled_at']),
      dispatchId: row['dispatch_id'] as String?,
      driverId: row['driver_id'] as String?,
      driverName: row['driver_name'] as String?,
      driverPhone: row['driver_phone'] as String?,
      dispatchedDate: _readDateTime(row['dispatched_date']),
      claimNote: row['claim_note'] as String?,
      updatedAt: _readRequiredDateTime(row, 'updated_at'),
    );
  }

  String _readRequiredString(Map<String, dynamic> row, String key) {
    final value = row[key] as String?;
    if (value == null || value.isEmpty) {
      throw StateError('Server parcel is missing $key.');
    }
    return value;
  }

  DateTime _readRequiredDateTime(Map<String, dynamic> row, String key) {
    final value = _readDateTime(row[key]);
    if (value == null) {
      throw StateError('Server parcel is missing $key.');
    }
    return value;
  }

  int _readRequiredInt(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw StateError('Server parcel is missing $key.');
  }

  double _readRequiredDouble(Map<String, dynamic> row, String key) {
    final value = _readDouble(row[key]);
    if (value == null) {
      throw StateError('Server parcel is missing $key.');
    }
    return value;
  }

  double? _readDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
