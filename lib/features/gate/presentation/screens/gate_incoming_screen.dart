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

class GateIncomingScreen extends ConsumerWidget {
  const GateIncomingScreen({super.key});

  static const routeName = '/gate-incoming';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(gateIncomingListsProvider);
    return AppScaffold(
      title: 'Incoming Parcels',
      drawer: const AppDrawer(currentRoute: routeName),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(gateIncomingListsProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createIncoming(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Incoming'),
      ),
      body: listsAsync.when(
        loading: AppLoading.new,
        error: (error, _) => _ErrorBody(error: error),
        data: (lists) => lists.isEmpty
            ? const AppEmptyState(
                title: 'No incoming lists yet',
                message: 'Create a list and select the arriving driver.',
              )
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(gateIncomingListsProvider),
                child: ListView.separated(
                  padding: AppSpacing.screenPadding,
                  itemCount: lists.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) =>
                      _IncomingCard(incoming: lists[index]),
                ),
              ),
      ),
    );
  }

  Future<void> _createIncoming(BuildContext context, WidgetRef ref) async {
    final driver = await _pickDriver(context, ref);
    if (driver == null || !context.mounted) return;
    await _run(
      context,
      () => ref.read(gateRepositoryProvider).createIncoming(driver.id),
      onSuccess: () => ref.invalidate(gateIncomingListsProvider),
    );
  }
}

class _IncomingCard extends ConsumerWidget {
  const _IncomingCard({required this.incoming});

  final GateIncoming incoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(gateIncomingEntriesProvider(incoming.id));
    final drivers = ref.watch(gateDriversProvider).asData?.value ?? const [];
    final driver = drivers
        .where((item) => item.id == incoming.driverId)
        .firstOrNull;
    return Card(
      child: ExpansionTile(
        title: Text(driver?.name ?? 'Driver'),
        subtitle: Text(
          '${_date(incoming.incomingDate)}  |  ${_paymentLabel(incoming.paymentStatus)}'
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
            data: (entries) => Column(
              children: [
                _Totals(entries: entries),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('No parcels attached.'),
                  ),
                ...entries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.receiverName),
                    subtitle: Text(
                      '${entry.receiverPhone}  |  ${entry.destinationTown}'
                      '  |  ${_paymentLabel(entry.paymentStatus)}'
                      '${entry.claimed ? '  |  claimed' : ''}',
                    ),
                    onTap: () => _showEntryDetail(context, entry),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) =>
                          _entryAction(context, ref, entry, action),
                      itemBuilder: (_) => [
                        if (!entry.claimed)
                          const PopupMenuItem(
                            value: 'claim',
                            child: Text('Mark Claimed'),
                          ),
                        if (!entry.claimed &&
                            !incoming.isPaid &&
                            entry.isManual)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                        if (!entry.claimed && !incoming.isPaid)
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!incoming.isPaid)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _attachExisting(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Tracking ID'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addManual(context, ref),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Manual Parcel'),
                ),
                FilledButton.icon(
                  onPressed: () => _markPaid(context, ref),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Driver Paid'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _attachExisting(BuildContext context, WidgetRef ref) async {
    final trackingId = await _promptText(
      context,
      'Attach Parcel',
      'Tracking ID',
    );
    if (trackingId == null || !context.mounted) return;
    final preview = await _lookupIncomingParcel(context, ref, trackingId);
    if (preview == null || !context.mounted) return;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (_) => _IncomingParcelPreviewDialog(preview: preview),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(gateRepositoryProvider)
          .attachExistingIncoming(incoming.id, trackingId),
      onSuccess: () => ref.invalidate(gateIncomingEntriesProvider(incoming.id)),
      errorDialogTitle: 'ပါဆယ်ထည့်၍ မရပါ',
    );
  }

  Future<GateIncomingParcelPreview?> _lookupIncomingParcel(
    BuildContext context,
    WidgetRef ref,
    String trackingId,
  ) async {
    try {
      return await ref
          .read(gateRepositoryProvider)
          .lookupIncomingParcel(incoming.id, trackingId);
    } catch (error) {
      if (!context.mounted) return null;
      await _showErrorDialog(context, 'ပါဆယ်ရှာမတွေ့ပါ', error);
      return null;
    }
  }

  Future<void> _addManual(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<_ManualIncomingValue>(
      context: context,
      builder: (_) => const _ManualIncomingDialog(),
    );
    if (value == null || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(gateRepositoryProvider)
          .addManualIncoming(
            incomingId: incoming.id,
            receiverName: value.receiverName,
            receiverPhone: value.receiverPhone,
            destinationTown: value.destinationTown,
            paymentStatus: value.paymentStatus,
            totalCharges: value.totalCharges,
            cashAdvance: value.cashAdvance,
            note: value.note,
          ),
      onSuccess: () => ref.invalidate(gateIncomingEntriesProvider(incoming.id)),
    );
  }

  Future<void> _markPaid(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<_PaidValue>(
      context: context,
      builder: (_) => const _PaidDialog(),
    );
    if (value == null || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(gateRepositoryProvider)
          .markIncomingPaid(
            incomingId: incoming.id,
            amount: value.amount,
            note: value.note,
          ),
      onSuccess: () => ref.invalidate(gateIncomingListsProvider),
    );
  }

  Future<void> _entryAction(
    BuildContext context,
    WidgetRef ref,
    GateIncomingEntry entry,
    String action,
  ) async {
    if (action == 'remove') {
      final confirmed = await _confirmRemove(context);
      if (!confirmed || !context.mounted) return;
      await _run(
        context,
        () => ref.read(gateRepositoryProvider).removeIncomingEntry(entry.id),
        onSuccess: () =>
            ref.invalidate(gateIncomingEntriesProvider(incoming.id)),
      );
      return;
    }
    if (action == 'edit') {
      final value = await showDialog<_ManualIncomingValue>(
        context: context,
        builder: (_) => _ManualIncomingDialog(entry: entry),
      );
      if (value == null || !context.mounted) return;
      await _run(
        context,
        () => ref
            .read(gateRepositoryProvider)
            .updateManualIncoming(
              entryId: entry.id,
              receiverName: value.receiverName,
              receiverPhone: value.receiverPhone,
              destinationTown: value.destinationTown,
              paymentStatus: value.paymentStatus,
              totalCharges: value.totalCharges,
              cashAdvance: value.cashAdvance,
              note: value.note,
            ),
        onSuccess: () =>
            ref.invalidate(gateIncomingEntriesProvider(incoming.id)),
      );
      return;
    }
    final claim = await showDialog<_ClaimValue>(
      context: context,
      builder: (_) => _ClaimDialog(entry: entry),
    );
    if (claim == null || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(gateRepositoryProvider)
          .claimIncomingEntry(
            entryId: entry.id,
            claimNote: claim.note,
            paymentStatus: claim.paymentStatus,
          ),
      onSuccess: () => ref.invalidate(gateIncomingEntriesProvider(incoming.id)),
    );
  }

  Future<void> _showEntryDetail(BuildContext context, GateIncomingEntry entry) {
    return showDialog<void>(
      context: context,
      builder: (_) => _IncomingEntryDetailDialog(entry: entry),
    );
  }

  Future<bool> _confirmRemove(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove parcel?'),
            content: const Text(
              'This parcel will be removed from the incoming list.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _IncomingEntryDetailDialog extends StatelessWidget {
  const _IncomingEntryDetailDialog({required this.entry});

  final GateIncomingEntry entry;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(entry.receiverName),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detail('Receiver Name', entry.receiverName),
            _detail('Receiver Phone', entry.receiverPhone),
            _detail('Destination Town', entry.destinationTown),
            _detail('Tracking ID', entry.trackingId ?? 'Manual parcel'),
            _detail('Payment Status', _paymentLabel(entry.paymentStatus)),
            _detail('Charges', entry.totalCharges.toStringAsFixed(0)),
            _detail('Cash Advance', entry.cashAdvance.toStringAsFixed(0)),
            _detail('Status', entry.claimed ? 'Claimed' : 'Arrived'),
            if ((entry.note ?? '').isNotEmpty) _detail('Note', entry.note!),
            if ((entry.claimNote ?? '').isNotEmpty)
              _detail('Claim Note', entry.claimNote!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xxs),
          Text(value),
        ],
      ),
    );
  }
}

class _IncomingParcelPreviewDialog extends StatelessWidget {
  const _IncomingParcelPreviewDialog({required this.preview});

  final GateIncomingParcelPreview preview;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Parcel'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detail('Tracking ID', preview.trackingId),
            _detail('Receiver Name', preview.receiverName),
            _detail('Receiver Phone', preview.receiverPhone),
            _detail('Destination Town', preview.destinationTown),
            _detail('Payment Status', _paymentLabel(preview.paymentStatus)),
            _detail('Charges', preview.totalCharges.toStringAsFixed(0)),
            _detail('Cash Advance', preview.cashAdvance.toStringAsFixed(0)),
            if ((preview.note ?? '').isNotEmpty) _detail('Note', preview.note!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirm Attach'),
        ),
      ],
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xxs),
          Text(value),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.entries});

  final List<GateIncomingEntry> entries;

  @override
  Widget build(BuildContext context) {
    final charges = entries.fold<double>(
      0,
      (sum, item) => sum + item.totalCharges,
    );
    final advances = entries.fold<double>(
      0,
      (sum, item) => sum + item.cashAdvance,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        '${entries.length} parcels  |  Charges ${charges.toStringAsFixed(0)}'
        '  |  Advance ${advances.toStringAsFixed(0)}'
        '  |  Balance ${(charges - advances).toStringAsFixed(0)}',
      ),
    );
  }
}

class _ManualIncomingDialog extends StatefulWidget {
  const _ManualIncomingDialog({this.entry});

  final GateIncomingEntry? entry;

  @override
  State<_ManualIncomingDialog> createState() => _ManualIncomingDialogState();
}

class _ManualIncomingDialogState extends State<_ManualIncomingDialog> {
  final formKey = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.entry?.receiverName);
  late final phone = TextEditingController(text: widget.entry?.receiverPhone);
  late final town = TextEditingController(text: widget.entry?.destinationTown);
  late final charges = TextEditingController(
    text: widget.entry?.totalCharges.toStringAsFixed(0) ?? '0',
  );
  late final advance = TextEditingController(
    text: widget.entry?.cashAdvance.toStringAsFixed(0) ?? '0',
  );
  late final note = TextEditingController(text: widget.entry?.note);
  late String payment = widget.entry?.paymentStatus ?? 'unpaid';

  @override
  void dispose() {
    for (final controller in [name, phone, town, charges, advance, note]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        const Icon(Icons.edit_note_rounded),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            widget.entry == null ? 'Manual Parcel' : 'Edit Manual Parcel',
          ),
        ),
      ],
    ),
    content: SingleChildScrollView(
      child: Form(
        key: formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Receiver Information'),
              _manualField(
                name,
                'Receiver Name',
                icon: Icons.person_outline_rounded,
                required: true,
              ),
              _manualField(
                phone,
                'Receiver Phone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                required: true,
              ),
              _manualField(
                town,
                'Destination Town',
                icon: Icons.location_on_outlined,
                required: true,
              ),
              _sectionTitle('Payment Information'),
              _manualField(
                charges,
                'Charges',
                icon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
                amount: true,
              ),
              _manualField(
                advance,
                'Cash Advance',
                icon: Icons.account_balance_wallet_outlined,
                keyboardType: TextInputType.number,
                amount: true,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: DropdownButtonFormField<String>(
                  initialValue: payment,
                  decoration: const InputDecoration(
                    labelText: 'Payment Status',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'unpaid',
                      child: Text('ငွေတောင်းရန်'),
                    ),
                    DropdownMenuItem(
                      value: 'paid',
                      child: Text('ငွေရှင်းပြီး'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => payment = value ?? payment),
                ),
              ),
              _sectionTitle('Note'),
              _manualField(
                note,
                'Optional note',
                icon: Icons.notes_rounded,
                keyboardType: TextInputType.multiline,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: () => _save(context),
        icon: Icon(
          widget.entry == null ? Icons.add_rounded : Icons.save_rounded,
        ),
        label: Text(widget.entry == null ? 'Add' : 'Save'),
      ),
    ],
  );

  void _save(BuildContext context) {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final total = double.tryParse(charges.text.trim());
    final cash = double.tryParse(advance.text.trim());
    if (total == null || cash == null) return;
    Navigator.pop(
      context,
      _ManualIncomingValue(
        name.text,
        phone.text,
        town.text,
        payment,
        total,
        cash,
        note.text,
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

  Widget _manualField(
    TextEditingController controller,
    String label, {
    required IconData icon,
    bool required = false,
    bool amount = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (required && text.isEmpty) return 'Required';
          if (!amount) return null;
          final parsed = double.tryParse(text);
          if (parsed == null) return 'Enter an amount';
          if (parsed < 0) return 'Cannot be negative';
          return null;
        },
      ),
    );
  }
}

class _PaidDialog extends StatefulWidget {
  const _PaidDialog();
  @override
  State<_PaidDialog> createState() => _PaidDialogState();
}

class _PaidDialogState extends State<_PaidDialog> {
  final formKey = GlobalKey<FormState>();
  final amount = TextEditingController();
  final note = TextEditingController();
  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Row(
      children: [
        Icon(Icons.payments_outlined),
        SizedBox(width: AppSpacing.xs),
        Expanded(child: Text('Driver Payment')),
      ],
    ),
    content: SingleChildScrollView(
      child: Form(
        key: formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ကားသမားကို ပေးချေသည့် ငွေပမာဏကို ဖြည့်ပါ။',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: amount,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null) return 'Enter an amount';
                  if (parsed < 0) return 'Cannot be negative';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: note,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Optional note',
                  prefixIcon: Icon(Icons.notes_rounded),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: () {
          if (!(formKey.currentState?.validate() ?? false)) return;
          final value = double.tryParse(amount.text.trim());
          if (value == null) return;
          Navigator.pop(context, _PaidValue(value, note.text));
        },
        icon: const Icon(Icons.check_rounded),
        label: const Text('Mark Paid'),
      ),
    ],
  );
}

class _ClaimDialog extends StatefulWidget {
  const _ClaimDialog({required this.entry});
  final GateIncomingEntry entry;
  @override
  State<_ClaimDialog> createState() => _ClaimDialogState();
}

class _ClaimDialogState extends State<_ClaimDialog> {
  final note = TextEditingController();
  late String payment = widget.entry.paymentStatus;
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mark Claimed'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _field(note, 'Claim Note'),
        if (widget.entry.isManual)
          DropdownButtonFormField<String>(
            initialValue: payment,
            decoration: const InputDecoration(labelText: 'Payment Status'),
            items: const [
              DropdownMenuItem(value: 'unpaid', child: Text('ငွေတောင်းရန်')),
              DropdownMenuItem(value: 'paid', child: Text('ငွေရှင်းပြီး')),
            ],
            onChanged: (value) => setState(() => payment = value ?? payment),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (note.text.trim().isEmpty) return;
          Navigator.pop(
            context,
            _ClaimValue(note.text, widget.entry.isManual ? payment : null),
          );
        },
        child: const Text('Confirm'),
      ),
    ],
  );
}

Widget _field(
  TextEditingController controller,
  String label, {
  bool number = false,
}) => TextField(
  controller: controller,
  keyboardType: number ? TextInputType.number : TextInputType.text,
  decoration: InputDecoration(labelText: label),
);

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
  BuildContext context,
  String title,
  String label,
) async {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        GateTextPromptDialog(title: title, label: label, confirmLabel: 'Add'),
  );
}

Future<void> _run(
  BuildContext context,
  Future<void> Function() action, {
  required VoidCallback onSuccess,
  String? errorDialogTitle,
}) async {
  try {
    await action();
    onSuccess();
  } catch (error) {
    if (!context.mounted) return;
    if (errorDialogTitle != null) {
      await _showErrorDialog(context, errorDialogTitle, error);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

Future<void> _showErrorDialog(
  BuildContext context,
  String title,
  Object error,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(_userFriendlyIncomingError(error)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

String _userFriendlyIncomingError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('parcel not found')) {
    return 'ဤ Tracking ID ဖြင့် ပါဆယ်မတွေ့ပါ။ Tracking ID ကို ပြန်စစ်ပေးပါ။';
  }
  if (message.contains('claimed parcel cannot be received again') ||
      message.contains('parcel is already claimed')) {
    return 'ဤပါဆယ်ကို ပိုင်ရှင်ထံ ပေးအပ်ပြီးဖြစ်သောကြောင့် ထပ်မံထည့်၍ မရပါ။';
  }
  if (message.contains('only dispatched parcels can be received')) {
    return 'ဤပါဆယ်သည် ကားဖြင့်ပို့ထားသော အခြေအနေမဟုတ်သေးသောကြောင့် လက်ခံ၍ မရပါ။';
  }
  if (message.contains('parcel is already attached to an incoming list')) {
    return 'ဤပါဆယ်ကို Incoming list တစ်ခုထဲတွင် ထည့်ထားပြီးဖြစ်ပါသည်။';
  }
  if (message.contains('paid incoming list cannot be edited')) {
    return 'ကားသမားကို ငွေရှင်းပြီးသော list ဖြစ်သောကြောင့် ပါဆယ်ထပ်ထည့်၍ မရပါ။';
  }
  if (message.contains('incoming list not found')) {
    return 'Incoming list ကို ရှာမတွေ့ပါ။ စာမျက်နှာကို Refresh လုပ်ပြီး ပြန်စမ်းပါ။';
  }
  if (message.contains('gate staff access required')) {
    return 'ဤလုပ်ဆောင်ချက်ကို ဂိတ်အကောင့်ဖြင့်သာ အသုံးပြုနိုင်ပါသည်။';
  }
  return 'လုပ်ဆောင်ချက် မအောင်မြင်ပါ။ အင်တာနက်လိုင်းကို စစ်ပြီး ပြန်စမ်းပါ။';
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _paymentLabel(String value) => switch (value) {
  'paid' => 'ငွေရှင်းပြီး',
  'unpaid' => 'ငွေတောင်းရန်',
  _ => value,
};

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: AppSpacing.screenPadding, child: Text(error.toString()));
}

class _ManualIncomingValue {
  const _ManualIncomingValue(
    this.receiverName,
    this.receiverPhone,
    this.destinationTown,
    this.paymentStatus,
    this.totalCharges,
    this.cashAdvance,
    this.note,
  );
  final String receiverName;
  final String receiverPhone;
  final String destinationTown;
  final String paymentStatus;
  final double totalCharges;
  final double cashAdvance;
  final String note;
}

class _PaidValue {
  const _PaidValue(this.amount, this.note);
  final double amount;
  final String note;
}

class _ClaimValue {
  const _ClaimValue(this.note, this.paymentStatus);
  final String note;
  final String? paymentStatus;
}
