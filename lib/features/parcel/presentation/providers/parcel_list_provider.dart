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

final parcelListProvider = Provider.autoDispose<AsyncValue<List<ParcelModel>>>((
  ref,
) {
  final filters = ref.watch(parcelListFilterProvider);
  final parcelsAsync = ref.watch(parcelHistoryProvider);
  final profileAsync = ref.watch(staffProfileProvider);

  return parcelsAsync.when(
    data: (parcels) => profileAsync.when(
      data: (profile) => AsyncValue.data(
        parcels
            .where((parcel) => _matchesBranchAccess(parcel, profile))
            .where((parcel) => _matchesFilter(parcel, filters))
            .toList(),
      ),
      loading: AsyncValue.loading,
      error: AsyncValue.error,
    ),
    loading: AsyncValue.loading,
    error: AsyncValue.error,
  );
});

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

bool _matchesFilter(ParcelModel parcel, ParcelListFilterState filters) {
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

  final query = filters.query.toLowerCase();
  if (query.isEmpty) {
    return true;
  }

  return _contains(parcel.trackingId, query) ||
      _contains(parcel.receiverName, query) ||
      _contains(parcel.receiverPhone, query);
}

bool _contains(String value, String query) {
  return value.toLowerCase().contains(query);
}
