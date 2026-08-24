import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/enums/parcel_status.dart';
import '../../../../data/models/parcel.dart';
import '../../../../providers/parcel_repository_provider.dart';
import '../../../auth/data/models/staff_profile.dart';
import '../../../auth/providers/auth_provider.dart';

class ParcelListFilterState {
  const ParcelListFilterState({
    this.query = '',
    this.status,
    this.startDate,
    this.endDate,
  });

  final String query;
  final ParcelStatus? status;
  final DateTime? startDate;
  final DateTime? endDate;

  ParcelListFilterState copyWith({
    String? query,
    ParcelStatus? status,
    bool clearStatus = false,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
  }) {
    return ParcelListFilterState(
      query: query ?? this.query,
      status: clearStatus ? null : status ?? this.status,
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
    );
  }
}

class ParcelListFilterNotifier extends Notifier<ParcelListFilterState> {
  @override
  ParcelListFilterState build() => const ParcelListFilterState();

  void updateQuery(String value) {
    state = state.copyWith(query: value.trim());
  }

  void updateStatus(ParcelStatus? value) {
    state = state.copyWith(status: value, clearStatus: value == null);
  }

  void updateDateRange({DateTime? startDate, DateTime? endDate}) {
    state = state.copyWith(
      startDate: startDate,
      clearStartDate: startDate == null,
      endDate: endDate,
      clearEndDate: endDate == null,
    );
  }

  void clearFilters() {
    state = const ParcelListFilterState();
  }
}

final parcelListFilterProvider =
    NotifierProvider.autoDispose<
      ParcelListFilterNotifier,
      ParcelListFilterState
    >(ParcelListFilterNotifier.new);

final parcelHistoryProvider = StreamProvider.autoDispose<List<ParcelModel>>((
  ref,
) {
  final repository = ref.watch(parcelRepositoryProvider);
  return repository.watchParcels();
});

final branchParcelHistoryProvider =
    Provider.autoDispose<AsyncValue<List<ParcelModel>>>((ref) {
      final parcelsAsync = ref.watch(parcelHistoryProvider);
      final profileAsync = ref.watch(staffProfileProvider);

      return parcelsAsync.when(
        data: (parcels) => profileAsync.when(
          data: (profile) => AsyncValue.data(
            parcels
                .where((parcel) => _matchesBranchAccess(parcel, profile))
                .toList(),
          ),
          loading: AsyncValue.loading,
          error: AsyncValue.error,
        ),
        loading: AsyncValue.loading,
        error: AsyncValue.error,
      );
    });

final parcelListProvider = Provider.autoDispose<AsyncValue<List<ParcelModel>>>((
  ref,
) {
  final filters = ref.watch(parcelListFilterProvider);
  final parcelsAsync = ref.watch(branchParcelHistoryProvider);

  return parcelsAsync.when(
    data: (parcels) => AsyncValue.data(
      _filterParentParcels(parcels: parcels, filters: filters),
    ),
    loading: AsyncValue.loading,
    error: AsyncValue.error,
  );
});

List<ParcelModel> _filterParentParcels({
  required List<ParcelModel> parcels,
  required ParcelListFilterState filters,
}) {
  final parentParcels = parcels
      .where((parcel) => !_isSplitChild(parcel))
      .toList();
  final childParcels = parcels.where(_isSplitChild).toList();
  final matchingChildParentTrackingIds = _matchingChildParentTrackingIds(
    children: childParcels,
    filters: filters,
  );

  return parentParcels.where((parcel) {
    final query = filters.query.trim();
    if (!_matchesStatusAndDate(parcel, filters)) {
      return false;
    }

    if (query.isEmpty) {
      return true;
    }

    if (_matchesSearch(parcel, query.toLowerCase())) {
      return true;
    }

    return matchingChildParentTrackingIds.contains(
      parcel.trackingId.toUpperCase(),
    );
  }).toList();
}

Set<String> _matchingChildParentTrackingIds({
  required List<ParcelModel> children,
  required ParcelListFilterState filters,
}) {
  final query = filters.query.toLowerCase().trim();
  if (query.isEmpty) {
    return const {};
  }

  return children
      .where((child) => _matchesSearch(child, query))
      .map(_parentTrackingIdFromChild)
      .whereType<String>()
      .map((trackingId) => trackingId.toUpperCase())
      .toSet();
}

bool _matchesBranchAccess(ParcelModel parcel, StaffProfile? profile) {
  if (profile == null) {
    return false;
  }
  if (profile.isAdmin) {
    return true;
  }

  final branchId = profile.branchId;
  if (branchId != null && branchId.isNotEmpty && parcel.branchId == branchId) {
    return true;
  }

  final cityCode = profile.branchCityCode;
  return cityCode != null &&
      cityCode.isNotEmpty &&
      parcel.cityCode.toUpperCase() == cityCode.toUpperCase();
}

bool _matchesStatusAndDate(ParcelModel parcel, ParcelListFilterState filters) {
  if (filters.status != null && parcel.status != filters.status) {
    return false;
  }

  if (filters.startDate != null &&
      parcel.createdAt.isBefore(filters.startDate!)) {
    return false;
  }

  if (filters.endDate != null && parcel.createdAt.isAfter(filters.endDate!)) {
    return false;
  }

  return true;
}

bool _matchesSearch(ParcelModel parcel, String query) {
  return _contains(parcel.trackingId, query) ||
      _contains(parcel.receiverName, query) ||
      _contains(parcel.receiverPhone, query);
}

bool _contains(String value, String query) {
  return value.toLowerCase().contains(query);
}

bool _isSplitChild(ParcelModel parcel) {
  return (parcel.parentParcelId ?? '').isNotEmpty ||
      (parcel.splitIndex ?? '').isNotEmpty ||
      _parentTrackingIdFromChild(parcel) != null;
}

String? _parentTrackingIdFromChild(ParcelModel parcel) {
  final trackingId = parcel.trackingId.trim();
  final splitIndex = parcel.splitIndex?.trim();
  if (splitIndex != null &&
      splitIndex.isNotEmpty &&
      trackingId.toUpperCase().endsWith('-${splitIndex.toUpperCase()}')) {
    return trackingId.substring(0, trackingId.length - splitIndex.length - 1);
  }

  final match = RegExp(
    r'^(.+-\d{6}-\d{4})-[A-Z]$',
    caseSensitive: false,
  ).firstMatch(trackingId);
  return match?.group(1);
}
