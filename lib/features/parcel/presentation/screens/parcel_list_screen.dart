import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/enums/parcel_status.dart';
import '../../../../providers/printer_provider.dart';
import '../../../../shared/helpers/printer_connect_navigation.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../voucher/presentation/screens/voucher_reprint_preview_screen.dart';
import '../providers/parcel_list_provider.dart';
import '../widgets/parcel_list_item.dart';

class ParcelListScreen extends ConsumerWidget {
  const ParcelListScreen({super.key});

  static const routeName = '/parcels';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcelsAsync = ref.watch(parcelListProvider);
    final filters = ref.watch(parcelListFilterProvider);
    final filterNotifier = ref.read(parcelListFilterProvider.notifier);
    final printerState = ref.watch(printerStateProvider);
    final theme = Theme.of(context);
    final printerConnected = printerState.isConnected;
    final printerBusy = printerState.isBusy || printerState.isScanning;

    return AppScaffold(
      title: 'TKT Parcel',
      drawer: const AppDrawer(currentRoute: routeName),
      actions: [
        IconButton(
          key: const Key('home-printer-action'),
          tooltip: 'Printers',
          onPressed: () {
            openPrinterConnectPage(context, ref);
          },
          icon: Icon(
            printerConnected
                ? Icons.bluetooth_connected
                : Icons.bluetooth_disabled,
            color: printerConnected
                ? Colors.green
                : printerBusy
                ? Colors.amber.shade700
                : theme.colorScheme.outline,
          ),
        ),
      ],
      body: parcelsAsync.when(
        data: (parcels) {
          final selectedDate = filters.startDate;
          final printerSummary = SectionCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Printer: ${printerState.observedConnectionState?.stage.name ?? printerState.connectionStage.name}',
                  ),
                  if (printerState.printProgress != null)
                    Text('Print: ${printerState.printProgress!.stage.name}'),
                  if (printerState.latestError != null)
                    Text(
                      'Error: ${printerState.latestError!.message}',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                ],
              ),
            ),
          );
          final filterCard = SectionCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  TextField(
                    onChanged: filterNotifier.updateQuery,
                    decoration: const InputDecoration(
                      hintText: 'Search tracking, receiver, phone',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<ParcelStatus?>(
                          initialValue: filters.status,
                          items: [
                            const DropdownMenuItem<ParcelStatus?>(
                              value: null,
                              child: Text('All Status'),
                            ),
                            ...ParcelStatus.values.map(
                              (status) => DropdownMenuItem<ParcelStatus?>(
                                value: status,
                                child: Text(status.value.toUpperCase()),
                              ),
                            ),
                          ],
                          onChanged: filterNotifier.updateStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
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
                              startDate: DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                              ),
                              endDate: DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                23,
                                59,
                                59,
                                999,
                              ),
                            );
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            selectedDate == null
                                ? 'Filter Date'
                                : '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        tooltip: 'Clear Filters',
                        onPressed: filterNotifier.clearFilters,
                        icon: const Icon(Icons.filter_alt_off),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

          if (parcels.isEmpty) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: printerSummary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: SizedBox(width: double.infinity, child: filterCard),
                ),
                const Expanded(
                  child: AppEmptyState(
                    title: 'No parcels yet',
                    message:
                        'Create your first parcel voucher to start operations.',
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: AppSpacing.screenPadding,
            itemCount: parcels.length + 2,
            separatorBuilder: (_, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return printerSummary;
              }
              if (index == 1) {
                return filterCard;
              }

              final parcel = parcels[index - 2];
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
          );
        },
        loading: () => const AppLoading(),
        error: (error, _) => AppErrorView(message: error.toString()),
      ),
    );
  }
}
