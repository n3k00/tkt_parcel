import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../data/models/gate_models.dart';
import '../../providers/gate_providers.dart';
import '../widgets/gate_text_prompt_dialog.dart';

class GateLedgerScreen extends ConsumerWidget {
  const GateLedgerScreen({super.key});

  static const routeName = '/gate-ledger';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgersAsync = ref.watch(gateLedgersProvider);

    return AppScaffold(
      title: 'Main Ledger',
      drawer: const AppDrawer(currentRoute: routeName),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(gateLedgersProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createLedger(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Ledger'),
      ),
      body: ledgersAsync.when(
        loading: AppLoading.new,
        error: (error, _) => _ErrorBody(error: error),
        data: (ledgers) => ledgers.isEmpty
            ? const AppEmptyState(
                title: 'No ledgers yet',
                message: 'Create a ledger and select the driver.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(gateLedgersProvider),
                child: ListView.separated(
                  padding: AppSpacing.screenPadding,
                  itemCount: ledgers.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) =>
                      _LedgerCard(ledger: ledgers[index]),
                ),
              ),
      ),
    );
  }

  Future<void> _createLedger(BuildContext context, WidgetRef ref) async {
    final driver = await _pickDriver(context, ref);
    if (driver == null || !context.mounted) return;
    await _run(
      context,
      () => ref.read(gateRepositoryProvider).createLedger(driver.id),
      onSuccess: () => ref.invalidate(gateLedgersProvider),
    );
  }
}

class _LedgerCard extends ConsumerWidget {
  const _LedgerCard({required this.ledger});

  final GateLedger ledger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(gateLedgerEntriesProvider(ledger.id));
    final drivers = ref.watch(gateDriversProvider).asData?.value ?? const [];
    final driver = drivers
        .where((item) => item.id == ledger.driverId)
        .firstOrNull;

    return Card(
      child: ExpansionTile(
        title: Text(driver?.name ?? 'Driver'),
        subtitle: Text(
          '${_date(ledger.ledgerDate)}  |  ${ledger.status.toUpperCase()}'
          '${driver == null ? '' : '  |  ${driver.vehicleNo}'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          entriesAsync.when(
            loading: AppLoading.new,
            error: (error, _) => _ErrorBody(error: error),
            data: (entries) => entries.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('No parcels attached.'),
                  )
                : Column(
                    children: entries
                        .map(
                          (entry) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(entry.trackingId),
                            subtitle: Text(entry.destinationTown),
                            trailing: ledger.isSettled
                                ? null
                                : IconButton(
                                    tooltip: 'Remove',
                                    onPressed: () =>
                                        _removeEntry(context, ref, entry.id),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          if (!ledger.isSettled)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _attach(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Attach Parcel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _settle(context, ref),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Settle'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _attach(BuildContext context, WidgetRef ref) async {
    final trackingId = await _promptText(
      context,
      title: 'Attach Parcel',
      label: 'Tracking ID',
    );
    if (trackingId == null || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(gateRepositoryProvider)
          .attachLedgerParcel(ledger.id, trackingId),
      onSuccess: () => ref.invalidate(gateLedgerEntriesProvider(ledger.id)),
    );
  }

  Future<void> _removeEntry(
    BuildContext context,
    WidgetRef ref,
    String entryId,
  ) async {
    await _run(
      context,
      () => ref.read(gateRepositoryProvider).removeLedgerEntry(entryId),
      onSuccess: () => ref.invalidate(gateLedgerEntriesProvider(ledger.id)),
    );
  }

  Future<void> _settle(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      'Settle ledger?',
      'Attached parcels will be marked as dispatched.',
    );
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      () => ref.read(gateRepositoryProvider).settleLedger(ledger.id),
      onSuccess: () {
        ref.invalidate(gateLedgersProvider);
        ref.invalidate(gateLedgerEntriesProvider(ledger.id));
      },
    );
  }
}

Future<GateDriver?> _pickDriver(BuildContext context, WidgetRef ref) async {
  final drivers = await ref.read(gateDriversProvider.future);
  if (!context.mounted) return null;
  return showDialog<GateDriver>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Select Driver'),
      children: drivers
          .map(
            (driver) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, driver),
              child: Text('${driver.name}  |  ${driver.vehicleNo}'),
            ),
          )
          .toList(),
    ),
  );
}

Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String label,
}) async {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        GateTextPromptDialog(title: title, label: label, confirmLabel: 'Save'),
  );
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> _run(
  BuildContext context,
  Future<void> Function() action, {
  required VoidCallback onSuccess,
}) async {
  try {
    await action();
    onSuccess();
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Text(error.toString()),
    );
  }
}
