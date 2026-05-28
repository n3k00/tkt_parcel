import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/enums/parcel_status.dart';
import '../../../../providers/parcel_repository_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../voucher/presentation/screens/voucher_reprint_preview_screen.dart';
import '../providers/parcel_list_provider.dart';
import '../widgets/parcel_list_item.dart';
import 'home_screen.dart';

class ParcelListScreen extends ConsumerStatefulWidget {
  const ParcelListScreen({super.key});

  static const routeName = '/parcels';

  @override
  ConsumerState<ParcelListScreen> createState() => _ParcelListScreenState();
}

class _ParcelListScreenState extends ConsumerState<ParcelListScreen> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parcelsAsync = ref.watch(parcelListProvider);
    final filters = ref.watch(parcelListFilterProvider);
    final filterNotifier = ref.read(parcelListFilterProvider.notifier);
    final selectedDate = filters.startDate;

    if (_searchController.text != filters.query) {
      _searchController.value = TextEditingValue(
        text: filters.query,
        selection: TextSelection.collapsed(offset: filters.query.length),
      );
    }

    return AppScaffold(
      title: 'Parcel List',
      drawer: const AppDrawer(currentRoute: ParcelListScreen.routeName),
      canPop: false,
      onBackNavigation: () {
        Navigator.of(context).pushReplacementNamed(HomeScreen.routeName);
      },
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
      ),
      actions: [
        PopupMenuButton<ParcelStatus?>(
          tooltip: filters.status == null
              ? 'Filter by status'
              : 'Status: ${_statusLabel(filters.status!)}',
          initialValue: filters.status,
          onSelected: filterNotifier.updateStatus,
          icon: Icon(
            filters.status == null
                ? Icons.filter_list_rounded
                : Icons.filter_alt_rounded,
          ),
          itemBuilder: (context) => [
            const PopupMenuItem<ParcelStatus?>(
              value: null,
              child: Text('All statuses'),
            ),
            ..._statusFilterOptions.map(
              (status) => PopupMenuItem<ParcelStatus?>(
                value: status,
                child: Text(_statusLabel(status)),
              ),
            ),
          ],
        ),
        IconButton(
          tooltip: selectedDate == null
              ? 'Filter by date'
              : 'Change date filter',
          onPressed: () => _pickDate(context, filterNotifier, selectedDate),
          icon: Icon(
            selectedDate == null
                ? Icons.calendar_today_outlined
                : Icons.event_available_rounded,
          ),
        ),
        if (selectedDate != null ||
            filters.query.isNotEmpty ||
            filters.status != null)
          IconButton(
            tooltip: 'Clear filters',
            onPressed: filterNotifier.clearFilters,
            icon: const Icon(Icons.filter_alt_off),
          ),
      ],
      body: parcelsAsync.when(
        data: (parcels) {
          final searchCard = SectionCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                key: const Key('parcel-history-search-field'),
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: filterNotifier.updateQuery,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: selectedDate == null
                      ? 'Search tracking, receiver, phone'
                      : 'Search in filtered date results',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: selectedDate == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.md),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                ),
              ),
            ),
          );

          return RefreshIndicator(
            onRefresh: _refreshParcels,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.screenPadding,
              itemCount: parcels.isEmpty ? 2 : parcels.length + 1,
              separatorBuilder: (_, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return searchCard;
                }

                if (parcels.isEmpty) {
                  final hasFilters =
                      filters.query.isNotEmpty ||
                      selectedDate != null ||
                      filters.status != null;
                  return SizedBox(
                    height: 360,
                    child: AppEmptyState(
                      title: hasFilters ? 'No parcels found' : 'No parcels yet',
                      message: hasFilters
                          ? 'Try a different tracking ID, receiver name, phone, date, or status filter.'
                          : 'Create your first parcel voucher to start operations.',
                    ),
                  );
                }

                final parcel = parcels[index - 1];
                return ParcelListItem(
                  parcel: parcel,
                  onTap: () {
                    if (parcel.id != null) {
                      Navigator.of(context).pushNamed(
                        VoucherReprintPreviewScreen.routeName,
                        arguments: parcel.id,
                      );
                    }
                  },
                );
              },
            ),
          );
        },
        loading: () => const AppLoading(),
        error: (error, _) => AppErrorView(message: error.toString()),
      ),
    );
  }

  Future<void> _refreshParcels() async {
    try {
      final syncRepository = await ref.read(syncRepositoryProvider.future);
      await syncRepository.pullParcelsFromServer();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parcel refresh failed. Check login and internet.'),
        ),
      );
    }
  }

  Future<void> _pickDate(
    BuildContext context,
    ParcelListFilterNotifier filterNotifier,
    DateTime? selectedDate,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) {
      return;
    }

    filterNotifier.updateDateRange(
      startDate: DateTime(picked.year, picked.month, picked.day),
      endDate: DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999),
    );
  }
}

const _statusFilterOptions = [
  ParcelStatus.received,
  ParcelStatus.dispatched,
  ParcelStatus.arrived,
  ParcelStatus.claimed,
];

String _statusLabel(ParcelStatus status) {
  return switch (status) {
    ParcelStatus.received => 'Received',
    ParcelStatus.dispatched => 'Dispatched',
    ParcelStatus.arrived => 'Arrived',
    ParcelStatus.claimed => 'Claimed',
    ParcelStatus.cancelled => 'Cancelled',
  };
}
