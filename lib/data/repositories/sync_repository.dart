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
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('Please sign in before refreshing parcels.');
    }

    final lastSyncedAt = _preferences.getParcelPullLastSyncedAt(scope: userId);
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
      await _preferences.setParcelPullLastSyncedAt(
        scope: userId,
        value: maxServerUpdatedAt,
      );
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

  Future<List<ParcelModel>> splitParcel({
    required ParcelModel parent,
    required List<SplitParcelInput> splits,
  }) async {
    if (_client.auth.currentSession == null) {
      throw StateError('Please sign in before splitting vouchers.');
    }

    if (parent.trackingId.trim().isEmpty) {
      throw StateError('Missing parent tracking ID.');
    }

    if (parent.status != ParcelStatus.received &&
        parent.status != ParcelStatus.partiallySplit) {
      throw StateError(
        'Only received or partially split parcels can be split.',
      );
    }

    final summary = await getSplitParcelSummary(parent);

    final response = await _client.rpc(
      'split_parcel',
      params: {
        'p_parent_parcel_id': summary.parentServerId,
        'p_splits': splits.map((split) => split.toServerJson()).toList(),
      },
    );

    final result = _readRpcObject(response);
    final syncedAt = DateTime.now();
    final rows = <Map<String, dynamic>>[];
    final parentResult = result['parent'];
    if (parentResult is Map) {
      rows.add(Map<String, dynamic>.from(parentResult));
    }
    final children = result['children'];
    if (children is List) {
      rows.addAll(
        children.whereType<Map>().map((row) => Map<String, dynamic>.from(row)),
      );
    }

    if (rows.isEmpty) {
      throw StateError('Server did not return split parcel data.');
    }

    final parcels = rows
        .map((row) => _parcelFromServerRow(row, syncedAt: syncedAt))
        .toList();
    for (final parcel in parcels) {
      await _parcelRepository.upsertSyncedParcel(parcel);
    }

    return parcels;
  }

  Future<SplitParcelSummary> getSplitParcelSummary(ParcelModel parent) async {
    if (_client.auth.currentSession == null) {
      throw StateError('Please sign in before splitting vouchers.');
    }

    final parentRow = await _client
        .from('parcels')
        .select('id, number_of_parcels, status, parcel_type')
        .eq('tracking_id', parent.trackingId)
        .maybeSingle();
    final parentServerId = parentRow?['id'] as String?;
    if (parentServerId == null || parentServerId.isEmpty) {
      throw StateError('Parent parcel was not found on the server.');
    }

    final parentStatus = ParcelStatus.fromValue(
      (parentRow?['status'] as String?) ?? ParcelStatus.received.value,
    );
    if (parentStatus != ParcelStatus.received &&
        parentStatus != ParcelStatus.partiallySplit) {
      throw StateError(
        'Only received or partially split parcels can be split.',
      );
    }

    final parentQuantity =
        _readInt(parentRow?['number_of_parcels']) ?? parent.numberOfParcels;
    final childRows = await _client
        .from('parcels')
        .select('number_of_parcels, split_index, parcel_type')
        .eq('parent_parcel_id', parentServerId)
        .order('split_index', ascending: true);
    final children = childRows.map((row) {
      return SplitParcelChildSummary(
        splitIndex: (row['split_index'] as String?) ?? '?',
        parcelType: (row['parcel_type'] as String?) ?? '',
        numberOfParcels: _readInt(row['number_of_parcels']) ?? 0,
      );
    }).toList();
    final usedQuantity = children.fold<int>(
      0,
      (sum, child) => sum + child.numberOfParcels,
    );
    final remainingQuantity = parentQuantity - usedQuantity;
    if (remainingQuantity <= 0) {
      throw StateError('Parent parcel is already fully split.');
    }

    return SplitParcelSummary(
      parentServerId: parentServerId,
      parentParcelType: (parentRow?['parcel_type'] as String?) ?? '',
      parentQuantity: parentQuantity,
      usedQuantity: usedQuantity,
      remainingQuantity: remainingQuantity,
      nextSplitIndex: String.fromCharCode(65 + childRows.length),
      children: children,
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

  Map<String, dynamic> _readRpcObject(Object? response) {
    if (response is Map) {
      return Map<String, dynamic>.from(response);
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
      parentParcelId: row['parent_parcel_id'] as String?,
      splitIndex: row['split_index'] as String?,
      splitCount: _readInt(row['split_count']),
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
    final value = _readInt(row[key]);
    if (value != null) return value;
    throw StateError('Server parcel is missing $key.');
  }

  int? _readInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
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

class SplitParcelInput {
  const SplitParcelInput({
    required this.numberOfParcels,
    required this.totalCharges,
    required this.cashAdvance,
    required this.parcelType,
    this.remark,
  });

  final int numberOfParcels;
  final double totalCharges;
  final double cashAdvance;
  final String parcelType;
  final String? remark;

  Map<String, dynamic> toServerJson() {
    return {
      'number_of_parcels': numberOfParcels,
      'total_charges': totalCharges,
      'cash_advance': cashAdvance,
      'parcel_type': parcelType,
      'remark': remark,
    };
  }
}

class SplitParcelSummary {
  const SplitParcelSummary({
    required this.parentServerId,
    required this.parentParcelType,
    required this.parentQuantity,
    required this.usedQuantity,
    required this.remainingQuantity,
    required this.nextSplitIndex,
    required this.children,
  });

  final String parentServerId;
  final String parentParcelType;
  final int parentQuantity;
  final int usedQuantity;
  final int remainingQuantity;
  final String nextSplitIndex;
  final List<SplitParcelChildSummary> children;
}

class SplitParcelChildSummary {
  const SplitParcelChildSummary({
    required this.splitIndex,
    required this.parcelType,
    required this.numberOfParcels,
  });

  final String splitIndex;
  final String parcelType;
  final int numberOfParcels;
}
