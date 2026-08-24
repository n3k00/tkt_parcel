import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:pos_printer_kit/pos_printer_kit.dart';

import '../../../../core/constants/voucher_layout.dart';
import '../../../../core/layout/app_responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/models/enums/parcel_status.dart';
import '../../../../data/models/parcel.dart';
import '../../../../data/repositories/sync_repository.dart';
import '../../../../providers/parcel_repository_provider.dart';
import '../../../../providers/printer_provider.dart';
import '../../../../shared/helpers/printer_connect_navigation.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../parcel/presentation/screens/parcel_list_screen.dart';
import '../../../printing/presentation/widgets/parcel_label_print_widgets.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../providers/voucher_preview_provider.dart';
import '../widgets/dispatch_info_section.dart';
import '../widgets/parcel_image_preview_card.dart';
import '../widgets/voucher_card.dart';

void _logLabelPrint(String message) {
  assert(() {
    debugPrint('[label_print] $message');
    return true;
  }());
}

Duration _labelPrintTimeout(int copies) {
  return Duration(seconds: 8 + copies.clamp(1, 20));
}

class VoucherReprintPreviewScreen extends ConsumerStatefulWidget {
  const VoucherReprintPreviewScreen({super.key, required this.parcelId});

  static const routeName = '/voucher/reprint';

  final int parcelId;

  @override
  ConsumerState<VoucherReprintPreviewScreen> createState() =>
      _VoucherReprintPreviewScreenState();
}

class _VoucherReprintPreviewScreenState
    extends ConsumerState<VoucherReprintPreviewScreen> {
  static const _printerSwitchDelay = Duration(milliseconds: 650);

  final GlobalKey _printBoundaryKey = GlobalKey();
  final GlobalKey _labelPrintKey = GlobalKey();
  bool _isReprinting = false;
  bool _isLabelPrinting = false;
  bool _isCapturingLabel = false;
  bool _isSplitting = false;
  bool _shouldRestoreReceiptPrinter = false;
  int? _labelQuantity;

  Future<void> _handlePrintLabel(VoucherPreviewData preview) async {
    if (_isLabelPrinting) {
      return;
    }

    final request = await showDialog<LabelPrintRequest>(
      context: context,
      builder: (_) => LabelPrintDialog(
        initialQuantity: _labelQuantity ?? preview.parcel.numberOfParcels,
      ),
    );
    if (request == null) {
      return;
    }
    final labelSettings = await ref.read(labelSettingsProvider.future);
    final labelSize = labelSettings.labelSize;

    setState(() {
      _labelQuantity = request.quantity;
      _isCapturingLabel = true;
    });

    try {
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final imageBytes = await ref
          .read(printServiceProvider)
          .captureWidgetAsPng(_labelPrintKey, pixelRatio: 1)
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () {
              throw StateError('Label image capture timed out.');
            },
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _isCapturingLabel = false;
        _isLabelPrinting = true;
      });

      final printerNotifier = ref.read(printerStateProvider.notifier);
      final selectedPrinter = request.printer;
      await printerNotifier.stopScan();
      if (!mounted) {
        return;
      }
      if (selectedPrinter == null) {
        await openPrinterConnectPage(context, ref);
        if (!mounted || !ref.read(printerStateProvider).isConnected) {
          return;
        }
      } else {
        await _connectTemporaryLabelPrinter(selectedPrinter);
      }

      final isIdle = await _waitForPrinterIdle();
      _logLabelPrint(
        'before tspl print '
        'connected=${ref.read(printerStateProvider).connectedPrinterName} '
        'busy=${ref.read(printerStateProvider).isBusy} idle=$isIdle '
        'copies=${request.quantity}',
      );
      if (!isIdle) {
        throw StateError('Printer is busy. Please try again.');
      }

      final success = await printerNotifier
          .printTsplLabelImage(
            imageBytes,
            copies: request.quantity,
            widthPx: labelSize.widthPx,
            heightPx: labelSize.heightPx,
            labelWidthMm: labelSize.widthMm,
            labelHeightMm: labelSize.heightMm,
          )
          .timeout(_labelPrintTimeout(request.quantity));
      _logLabelPrint('tspl print result=$success');
      if (success) {
        await _waitForLabelOutput(request.quantity);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Label printed successfully.'
                : ref.read(printerStateProvider).errorMessage ??
                      'Label print failed.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Label print failed: $error')));
      }
    } finally {
      await _restoreReceiptPrinter();
      if (mounted) {
        setState(() {
          _isLabelPrinting = false;
          _isCapturingLabel = false;
        });
      }
    }
  }

  PrinterDevice? _receiptPrinterBeforeLabelPrint;

  Future<void> _connectTemporaryLabelPrinter(PrinterDevice labelPrinter) async {
    final printerNotifier = ref.read(printerStateProvider.notifier);
    _receiptPrinterBeforeLabelPrint = ref
        .read(printerStateProvider)
        .connectedDevice;
    _shouldRestoreReceiptPrinter = false;

    if (_receiptPrinterBeforeLabelPrint?.id == labelPrinter.id) {
      await _waitForPrinterIdle();
      await Future<void>.delayed(_printerSwitchDelay);
      return;
    }

    if (_receiptPrinterBeforeLabelPrint != null) {
      _shouldRestoreReceiptPrinter = true;
      await printerNotifier.disconnect();
      await _waitForPrinterDisconnected(_receiptPrinterBeforeLabelPrint!.id);
      await Future<void>.delayed(_printerSwitchDelay);
    }

    await printerNotifier.connect(labelPrinter);
    final isReady = await _waitForPrinterConnection(labelPrinter.id);
    if (!isReady) {
      throw StateError(
        ref.read(printerStateProvider).errorMessage ??
            'Label printer connection failed.',
      );
    }
    await _waitForPrinterIdle();
    await Future<void>.delayed(_printerSwitchDelay);
  }

  Future<void> _restoreReceiptPrinter() async {
    final receiptPrinter = _receiptPrinterBeforeLabelPrint;
    final shouldRestore = _shouldRestoreReceiptPrinter;
    _receiptPrinterBeforeLabelPrint = null;
    _shouldRestoreReceiptPrinter = false;
    if (receiptPrinter == null || !shouldRestore) {
      return;
    }

    final printerNotifier = ref.read(printerStateProvider.notifier);
    final connectedPrinter = ref.read(printerStateProvider).connectedDevice;
    if (connectedPrinter?.id == receiptPrinter.id) {
      return;
    }

    try {
      await printerNotifier.disconnect();
      await _waitForPrinterDisconnected(connectedPrinter?.id);
      await Future<void>.delayed(_printerSwitchDelay);
      await printerNotifier.connect(receiptPrinter);
      await _waitForPrinterConnection(receiptPrinter.id);
      await _waitForPrinterIdle();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Label printed, but ${receiptPrinter.name} could not reconnect.',
            ),
          ),
        );
      }
    }
  }

  Future<bool> _waitForPrinterConnection(String printerId) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final connectedPrinter = ref.read(printerStateProvider).connectedDevice;
      if (connectedPrinter?.id == printerId) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  Future<bool> _waitForPrinterDisconnected(String? printerId) async {
    if (printerId == null) {
      return true;
    }

    for (var attempt = 0; attempt < 20; attempt++) {
      final connectedPrinter = ref.read(printerStateProvider).connectedDevice;
      if (connectedPrinter == null || connectedPrinter.id != printerId) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  Future<bool> _waitForPrinterIdle() async {
    for (var attempt = 0; attempt < 40; attempt++) {
      final printerState = ref.read(printerStateProvider);
      if (!printerState.isBusy && !printerState.isScanning) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  Future<void> _waitForLabelOutput(int copies) {
    final extraMs = copies.clamp(1, 20) * 350;
    return Future<void>.delayed(Duration(milliseconds: 900 + extraMs));
  }

  Future<void> _handleReprint(VoucherPreviewData preview) async {
    if (_isReprinting) {
      return;
    }

    setState(() {
      _isReprinting = true;
    });

    final printerNotifier = ref.read(printerStateProvider.notifier);
    final printerState = ref.read(printerStateProvider);

    try {
      if (!printerState.isConnected) {
        await openPrinterConnectPage(context, ref);
        if (!mounted || !ref.read(printerStateProvider).isConnected) {
          return;
        }
      }

      final imageBytes = await ref
          .read(printServiceProvider)
          .captureWidgetAsPng(_printBoundaryKey);
      final success = await printerNotifier.printImageBytes(imageBytes);

      if (!mounted) {
        return;
      }

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(printerStateProvider).errorMessage ??
                  'Voucher print failed.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voucher reprinted successfully.')),
      );
      Navigator.of(context).popUntil((route) {
        return route.settings.name == ParcelListScreen.routeName ||
            route.isFirst;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isReprinting = false;
        });
      }
    }
  }

  bool _canSplitVoucher(ParcelModel parcel) {
    return (parcel.status == ParcelStatus.received ||
            parcel.status == ParcelStatus.partiallySplit) &&
        parcel.parentParcelId == null &&
        parcel.splitIndex == null &&
        parcel.numberOfParcels > 0;
  }

  Future<void> _handleSplitVoucher(VoucherPreviewData preview) async {
    if (_isSplitting) {
      return;
    }

    setState(() {
      _isSplitting = true;
    });

    try {
      final syncRepository = await ref.read(syncRepositoryProvider.future);
      final summary = await syncRepository.getSplitParcelSummary(
        preview.parcel,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _isSplitting = false;
      });

      final split = await showDialog<SplitParcelInput>(
        context: context,
        builder: (_) =>
            _SplitVoucherDialog(parent: preview.parcel, summary: summary),
      );
      if (split == null) {
        return;
      }

      setState(() {
        _isSplitting = true;
      });

      final parcels = await syncRepository.splitParcel(
        parent: preview.parcel,
        splits: [split],
      );
      if (!mounted) {
        return;
      }

      ref.invalidate(voucherReprintPreviewProvider(widget.parcelId));
      final childIds = parcels
          .where((parcel) => parcel.parentParcelId != null)
          .map((parcel) => parcel.trackingId)
          .join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            childIds.isEmpty
                ? 'Child voucher created successfully.'
                : 'Child voucher created: $childIds',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cannot split/correct voucher'),
          content: Text(_friendlySplitError(error)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSplitting = false;
        });
      }
    }
  }

  String _friendlySplitError(Object error) {
    final message = error.toString();
    if (message.contains('sign in') ||
        message.contains('Authentication required')) {
      return 'Please sign in again before splitting this voucher.';
    }
    if (message.contains('not found')) {
      return 'This voucher was not found on the server. Refresh Parcel List and try again.';
    }
    if (message.contains('already fully split') ||
        message.contains('already split') ||
        message.contains('already has split')) {
      return 'This voucher has already been fully split.';
    }
    if (message.contains('Only received') ||
        message.contains('partially split')) {
      return 'Only received or partially split vouchers can be split.';
    }
    if (message.contains('quantity')) {
      return 'Split quantity is not valid. Total split quantity cannot exceed the parent quantity.';
    }
    if (message.contains('negative')) {
      return 'Charges and cash advance cannot be negative.';
    }
    return 'Split failed. Check internet connection, refresh Parcel List, and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final previewAsync = ref.watch(
      voucherReprintPreviewProvider(widget.parcelId),
    );
    final labelSettingsAsync = ref.watch(labelSettingsProvider);
    final printerState = ref.watch(printerStateProvider);
    final isProcessing =
        previewAsync.isLoading ||
        labelSettingsAsync.isLoading ||
        printerState.isBusy ||
        _isReprinting ||
        _isLabelPrinting ||
        _isSplitting;

    return AppScaffold(
      title: 'Reprint Voucher',
      actions: [
        IconButton(
          tooltip: 'Print Label',
          onPressed: isProcessing || !labelSettingsAsync.hasValue
              ? null
              : () {
                  final preview = previewAsync.asData?.value;
                  if (preview != null) {
                    _handlePrintLabel(preview);
                  }
                },
          icon: const Icon(Icons.label_outline),
        ),
      ],
      isBlocking:
          (_isReprinting ||
              _isLabelPrinting ||
              _isSplitting ||
              printerState.isBusy) &&
          !_isCapturingLabel,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final buttonWidth = math.min(
            AppResponsive.centeredContentWidth(
              context,
              horizontalPadding: AppSpacing.lg,
            ),
            720.0,
          );
          return SizedBox(
            width: buttonWidth,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
              onPressed: isProcessing
                  ? null
                  : () {
                      final preview = previewAsync.asData?.value;
                      if (preview != null) {
                        _handleReprint(preview);
                      }
                    },
              child: const Text('Reprint'),
            ),
          );
        },
      ),
      body: previewAsync.when(
        data: (preview) => Stack(
          clipBehavior: Clip.none,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final previewWidth = math.min(
                  AppResponsive.centeredContentWidth(
                    context,
                    horizontalPadding: AppSpacing.lg,
                  ),
                  VoucherLayout.previewPaperWidth,
                );
                return ListView(
                  padding: AppSpacing.screenPadding,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: previewWidth),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          alignment: Alignment.topCenter,
                          child: RepaintBoundary(
                            key: _printBoundaryKey,
                            child: VoucherCard(
                              parcel: preview.parcel,
                              qrPayload: preview.qrPayload,
                              setup: preview.setup,
                              isPrintable: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                    DispatchInfoSection(parcel: preview.parcel),
                    if (preview.splitChildren.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _SplitChildrenSection(
                        children: preview.splitChildren,
                        onChildTap: (child) {
                          final childId = child.id;
                          if (childId == null) {
                            return;
                          }
                          Navigator.of(context).pushNamed(
                            VoucherReprintPreviewScreen.routeName,
                            arguments: childId,
                          );
                        },
                      ),
                    ],
                    if (_canSplitVoucher(preview.parcel)) ...[
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: isProcessing
                            ? null
                            : () => _handleSplitVoucher(preview),
                        icon: const Icon(Icons.call_split_rounded),
                        label: const Text('Split / Correct Voucher'),
                      ),
                    ],
                    if ((preview.parcel.parcelImagePath ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      ParcelImagePreviewCard(
                        imagePath: preview.parcel.parcelImagePath!,
                      ),
                    ],
                    if (printerState.errorMessage != null &&
                        printerState.lastPrintableImageBytes != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: isProcessing
                            ? null
                            : () => ref
                                  .read(printerStateProvider.notifier)
                                  .retryLastPrint(),
                        child: const Text('Retry Print'),
                      ),
                    ],
                    if (printerState.lastPrintableImageBytes != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: isProcessing
                            ? null
                            : () => ref
                                  .read(printerStateProvider.notifier)
                                  .reprintLastVoucher(),
                        child: const Text('Reprint Last Voucher'),
                      ),
                    ],
                    const SizedBox(height: 104),
                  ],
                );
              },
            ),
            if (labelSettingsAsync.hasValue)
              Positioned(
                left: -10000,
                top: 0,
                child: RepaintBoundary(
                  key: _labelPrintKey,
                  child: SizedBox(
                    width: labelSettingsAsync.value!.labelSize.widthPx
                        .toDouble(),
                    child: ParcelLabelPreview(
                      settings: labelSettingsAsync.value!,
                      businessPhone: preview.setup.businessPhone,
                      name: preview.parcel.receiverName,
                      phone: preview.parcel.receiverPhone,
                      address: preview.parcel.toTown,
                      quantity: preview.parcel.numberOfParcels,
                      trackingId: preview.parcel.trackingId,
                      includeShadow: false,
                      includeBorder: false,
                      maxWidth: labelSettingsAsync.value!.labelSize.widthPx
                          .toDouble(),
                    ),
                  ),
                ),
              ),
          ],
        ),
        loading: () => const Padding(
          padding: AppSpacing.screenPadding,
          child: AppLoading(),
        ),
        error: (error, _) => Padding(
          padding: AppSpacing.screenPadding,
          child: AppErrorView(message: error.toString()),
        ),
      ),
    );
  }
}

class _SplitChildrenSection extends StatelessWidget {
  const _SplitChildrenSection({
    required this.children,
    required this.onChildTap,
  });

  final List<ParcelModel> children;
  final ValueChanged<ParcelModel> onChildTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.call_split_rounded, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Split Children / ခွဲထားသော ဘောင်ချာများ',
                    style: AppTextStyles.subtitle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final child in children) ...[
              _SplitChildRow(parcel: child, onTap: () => onChildTap(child)),
              if (child != children.last) const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _SplitChildRow extends StatelessWidget {
  const _SplitChildRow({required this.parcel, required this.onTap});

  final ParcelModel parcel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final driverName = parcel.driverName?.trim();

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.medium,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.medium,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.medium,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _statusColor(parcel.status),
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parcel.trackingId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.xs,
                        children: [
                          Text(
                            'Qty ${parcel.numberOfParcels}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Charges ${parcel.totalCharges.toStringAsFixed(0)}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            driverName == null || driverName.isEmpty
                                ? 'Driver မပါသေး'
                                : 'Driver $driverName',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.iconSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _statusColor(ParcelStatus status) {
  return switch (status) {
    ParcelStatus.received => AppColors.received,
    ParcelStatus.partiallySplit => AppColors.partiallySplit,
    ParcelStatus.dispatched => AppColors.dispatched,
    ParcelStatus.arrived => AppColors.arrived,
    ParcelStatus.claimed => AppColors.claimed,
    ParcelStatus.split => AppColors.split,
    ParcelStatus.cancelled => AppColors.cancelled,
  };
}

class _SplitVoucherDialog extends StatefulWidget {
  const _SplitVoucherDialog({required this.parent, required this.summary});

  final ParcelModel parent;
  final SplitParcelSummary summary;

  @override
  State<_SplitVoucherDialog> createState() => _SplitVoucherDialogState();
}

class _SplitVoucherDialogState extends State<_SplitVoucherDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _qty;
  late final TextEditingController _charges;
  late final TextEditingController _cashAdvance;
  late final TextEditingController _parcelType;
  late final TextEditingController _remark;

  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(
      text: widget.summary.remainingQuantity.toString(),
    );
    _charges = TextEditingController(text: '0');
    _cashAdvance = TextEditingController(text: '0');
    _parcelType = TextEditingController();
    _remark = TextEditingController(text: widget.parent.remark);
  }

  @override
  void dispose() {
    _qty.dispose();
    _charges.dispose();
    _cashAdvance.dispose();
    _parcelType.dispose();
    _remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.call_split_rounded),
          SizedBox(width: AppSpacing.xs),
          Expanded(child: Text('Split / Correct Voucher')),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.parent.trackingId,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Parent qty ${widget.summary.parentQuantity}  |  Split used ${widget.summary.usedQuantity}  |  Remaining ${widget.summary.remainingQuantity}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_isSingleQuantityCorrection) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Qty 1 voucher will be corrected as one child voucher. Use the child tracking ID for ledger and incoming flows.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _referenceCard(context),
                const SizedBox(height: AppSpacing.md),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Child ${widget.summary.nextSplitIndex}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _splitField(
                          _qty,
                          'Qty',
                          icon: Icons.inventory_2_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          readOnly: _isFixedQuantity,
                          helperText: _isFixedQuantity
                              ? 'Only 1 remaining, so qty is fixed.'
                              : null,
                          validator: _validateQty,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _splitField(
                          _charges,
                          'Charges',
                          icon: Icons.payments_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          validator: _validateAmount,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _splitField(
                          _cashAdvance,
                          'Cash Advance',
                          icon: Icons.account_balance_wallet_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          validator: _validateAmount,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _splitField(
                          _parcelType,
                          'Child Parcel Type',
                          icon: Icons.category_outlined,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            return text.isEmpty ? 'Required' : null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _splitField(
                          _remark,
                          'Remark',
                          icon: Icons.notes_rounded,
                          maxLines: 2,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                        ),
                      ],
                    ),
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
          onPressed: _confirm,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Review'),
        ),
      ],
    );
  }

  Widget _referenceCard(BuildContext context) {
    final children = widget.summary.children;

    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18),
                SizedBox(width: AppSpacing.xs),
                Text(
                  'Reference',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _referenceBlock(
              context,
              label: 'Parent Parcel Type',
              value: _parentReferenceType,
              helper: 'Parent qty ${widget.parent.numberOfParcels}',
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              for (final child in children)
                _referenceBlock(
                  context,
                  label: 'Child ${child.splitIndex}',
                  value: child.parcelType.isEmpty ? '-' : child.parcelType,
                  helper: 'Qty ${child.numberOfParcels}',
                ),
            ],
          ],
        ),
      ),
    );
  }

  String get _parentReferenceType {
    final localType = widget.parent.parcelType.trim();
    if (localType.isNotEmpty) {
      return localType;
    }
    return widget.summary.parentParcelType.trim();
  }

  bool get _isFixedQuantity => widget.summary.remainingQuantity == 1;

  bool get _isSingleQuantityCorrection =>
      widget.summary.parentQuantity == 1 &&
      widget.summary.usedQuantity == 0 &&
      widget.summary.remainingQuantity == 1;

  Widget _referenceBlock(
    BuildContext context, {
    required String label,
    required String value,
    required String helper,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final displayValue = value.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                displayValue.isEmpty ? 'Not set' : displayValue,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              helper,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (displayValue.isEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Parent parcel type is empty on this parcel.',
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirm() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final value = _readValue();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Split / Correction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parent: ${widget.parent.trackingId}'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Child ${widget.summary.nextSplitIndex}: '
              '${widget.parent.trackingId}-${widget.summary.nextSplitIndex}',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Qty ${value.numberOfParcels}, '
              'charges ${value.totalCharges.toStringAsFixed(0)}, '
              'advance ${value.cashAdvance.toStringAsFixed(0)}',
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'This creates one child voucher. The parent voucher will no longer be used for ledger and incoming flows.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context, value);
    }
  }

  SplitParcelInput _readValue() {
    return SplitParcelInput(
      numberOfParcels: int.parse(_qty.text.trim()),
      totalCharges: double.parse(_charges.text.trim()),
      cashAdvance: double.parse(_cashAdvance.text.trim()),
      parcelType: _parcelType.text.trim(),
      remark: _remark.text.trim().isEmpty ? null : _remark.text.trim(),
    );
  }

  String? _validateQty(String? value) {
    final qty = int.tryParse(value?.trim() ?? '');
    if (qty == null) return 'Required';
    if (qty <= 0) return 'Must be > 0';
    if (qty > widget.summary.remainingQuantity) {
      return 'Max ${widget.summary.remainingQuantity}';
    }
    return null;
  }

  String? _validateAmount(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    if (amount == null) return 'Required';
    if (amount < 0) return 'Cannot be negative';
    return null;
  }

  Widget _splitField(
    TextEditingController controller,
    String label, {
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool readOnly = false,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        helperText: helperText,
      ),
      validator: validator,
    );
  }
}
