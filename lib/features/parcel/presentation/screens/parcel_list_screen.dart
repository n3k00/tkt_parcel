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
import 'parcel_qr_scanner_screen.dart';

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
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: _buildSearchCard(
                  selectedDate: selectedDate,
                  filterNotifier: filterNotifier,
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshParcels,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    itemCount: parcels.isEmpty ? 1 : parcels.length,
                    separatorBuilder: (_, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      if (parcels.isEmpty) {
                        final hasFilters =
                            filters.query.isNotEmpty ||
                            selectedDate != null ||
                            filters.status != null;
                        return SizedBox(
                          height: 360,
                          child: AppEmptyState(
                            title: hasFilters
                                ? 'No parcels found'
                                : 'No parcels yet',
                            message: hasFilters
                                ? 'Try a different tracking ID, receiver name, phone, date, or status filter.'
                                : 'Create your first parcel voucher to start operations.',
                          ),
                        );
                      }

                      final parcel = parcels[index];
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
                ),
              ),
            ],
          );
        },
        loading: () => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: _buildSearchCard(
                selectedDate: selectedDate,
                filterNotifier: filterNotifier,
              ),
            ),
            const Expanded(child: AppLoading()),
          ],
        ),
        error: (error, _) => AppErrorView(message: error.toString()),
      ),
    );
  }

  Widget _buildSearchCard({
    required DateTime? selectedDate,
    required ParcelListFilterNotifier filterNotifier,
  }) {
    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (context, searchValue, _) {
            final hasSearchText = searchValue.text.trim().isNotEmpty;

            return TextField(
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
                suffixIcon: IconButton(
                  tooltip: hasSearchText ? 'Clear search' : 'Scan QR',
                  onPressed: hasSearchText
                      ? () => _clearSearch(filterNotifier)
                      : _scanParcelQr,
                  icon: hasSearchText
                      ? const Icon(Icons.close_rounded)
                      : const _ScanFrameIcon(),
                ),
              ),
            );
          },
        ),
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

  Future<void> _scanParcelQr() async {
    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ParcelQrScannerScreen()),
    );
    if (!mounted || scannedValue == null) {
      return;
    }

    final trackingId = _extractTrackingId(scannedValue);
    if (trackingId == null) {
      await _showScanMessage(
        title: 'QR ဖတ်လို့မရပါ',
        message: 'QR ထဲမှာ tracking ID မတွေ့ပါ။ Voucher QR ကိုပြန်စမ်းပါ။',
      );
      return;
    }

    final visibleParcels = ref
        .read(branchParcelHistoryProvider)
        .whenOrNull(data: (parcels) => parcels);
    if (visibleParcels == null) {
      await _showScanMessage(
        title: 'Parcel List မဖွင့်ရသေးပါ',
        message: 'Parcel history ကို ပြန်ဖွင့်ပြီး QR ကိုထပ် scan လုပ်ပါ။',
      );
      return;
    }

    final parcel = visibleParcels
        .where(
          (parcel) =>
              parcel.trackingId.toUpperCase() == trackingId.toUpperCase(),
        )
        .firstOrNull;

    final parcelId = parcel?.id;
    if (parcelId == null) {
      ref.read(parcelListFilterProvider.notifier).updateQuery(trackingId);
      await _showScanMessage(
        title: 'Parcel မတွေ့ပါ',
        message:
            '$trackingId ကို ဒီ account ရဲ့ local Parcel History ထဲမှာ မတွေ့ပါ။ Refresh လုပ်ပြီး ပြန်စမ်းပါ။',
      );
      return;
    }

    ref.read(parcelListFilterProvider.notifier).updateQuery(trackingId);
    await Navigator.of(
      context,
    ).pushNamed(VoucherReprintPreviewScreen.routeName, arguments: parcelId);
  }

  void _clearSearch(ParcelListFilterNotifier filterNotifier) {
    _searchController.clear();
    filterNotifier.updateQuery('');
    _searchFocusNode.requestFocus();
  }

  Future<void> _showScanMessage({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

String? _extractTrackingId(String value) {
  final trimmed = value.trim();
  final decoded = _safeDecodeQrValue(trimmed).toUpperCase();
  final match = RegExp(
    r'\b[A-Z]{2,5}-\d{6}-\d{4}(?:-[A-Z])?\b',
  ).firstMatch(decoded);
  return match?.group(0);
}

String _safeDecodeQrValue(String value) {
  try {
    return Uri.decodeFull(value);
  } on FormatException {
    return value;
  }
}

class _ScanFrameIcon extends StatelessWidget {
  const _ScanFrameIcon();

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Colors.black;
    return SizedBox.square(
      dimension: 24,
      child: CustomPaint(painter: _ScanFramePainter(color)),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.12;
    final radius = size.width * 0.10;
    final inset = strokeWidth / 2;
    final corner = size.width * 0.28;
    final midLineY = size.height * 0.52;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;

    void drawCorner(Path path) {
      canvas.drawPath(path, paint);
    }

    drawCorner(
      Path()
        ..moveTo(left, top + corner)
        ..lineTo(left, top + radius)
        ..quadraticBezierTo(left, top, left + radius, top)
        ..lineTo(left + corner, top),
    );
    drawCorner(
      Path()
        ..moveTo(right - corner, top)
        ..lineTo(right - radius, top)
        ..quadraticBezierTo(right, top, right, top + radius)
        ..lineTo(right, top + corner),
    );
    drawCorner(
      Path()
        ..moveTo(left, bottom - corner)
        ..lineTo(left, bottom - radius)
        ..quadraticBezierTo(left, bottom, left + radius, bottom)
        ..lineTo(left + corner, bottom),
    );
    drawCorner(
      Path()
        ..moveTo(right - corner, bottom)
        ..lineTo(right - radius, bottom)
        ..quadraticBezierTo(right, bottom, right, bottom - radius)
        ..lineTo(right, bottom - corner),
    );

    canvas.drawLine(
      Offset(size.width * 0.18, midLineY),
      Offset(size.width * 0.82, midLineY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

const _statusFilterOptions = [
  ParcelStatus.received,
  ParcelStatus.partiallySplit,
  ParcelStatus.dispatched,
  ParcelStatus.arrived,
  ParcelStatus.claimed,
  ParcelStatus.split,
];

String _statusLabel(ParcelStatus status) {
  return switch (status) {
    ParcelStatus.received => 'Received',
    ParcelStatus.partiallySplit => 'Partially Split',
    ParcelStatus.dispatched => 'Dispatched',
    ParcelStatus.arrived => 'Arrived',
    ParcelStatus.claimed => 'Claimed',
    ParcelStatus.split => 'Split',
    ParcelStatus.cancelled => 'Cancelled',
  };
}
