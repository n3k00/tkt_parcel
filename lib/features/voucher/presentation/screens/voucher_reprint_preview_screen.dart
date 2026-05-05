import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_printer_kit/pos_printer_kit.dart';

import '../../../../core/constants/voucher_layout.dart';
import '../../../../core/layout/app_responsive.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../providers/printer_provider.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../parcel/presentation/screens/parcel_list_screen.dart';
import '../../../printing/presentation/screens/printer_connect_screen.dart';
import '../../../printing/presentation/widgets/parcel_label_print_widgets.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../providers/voucher_preview_provider.dart';
import '../widgets/parcel_image_preview_card.dart';
import '../widgets/voucher_card.dart';

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
  final GlobalKey _printBoundaryKey = GlobalKey();
  final GlobalKey _labelPrintKey = GlobalKey();
  bool _isReprinting = false;
  bool _isLabelPrinting = false;
  bool _isCapturingLabel = false;
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
      if (selectedPrinter == null) {
        await Navigator.of(context).pushNamed(PrinterConnectScreen.routeName);
        if (!mounted || !ref.read(printerStateProvider).isConnected) {
          return;
        }
      } else {
        await _connectTemporaryLabelPrinter(selectedPrinter);
      }

      await printerNotifier.stopScan();
      final isIdle = await _waitForPrinterIdle();
      if (!isIdle) {
        throw StateError('Printer is busy. Please try again.');
      }

      final success = await printerNotifier.printTsplLabelImage(
        imageBytes,
        copies: request.quantity,
      );

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Label print failed: $error')),
        );
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
    _receiptPrinterBeforeLabelPrint = ref.read(printerStateProvider).connectedDevice;
    _shouldRestoreReceiptPrinter = false;

    if (_receiptPrinterBeforeLabelPrint?.id == labelPrinter.id) {
      return;
    }

    if (_receiptPrinterBeforeLabelPrint != null) {
      _shouldRestoreReceiptPrinter = true;
      await printerNotifier.disconnect();
    }

    await printerNotifier.connect(labelPrinter);
    final isReady = await _waitForPrinterConnection(labelPrinter.id);
    if (!isReady) {
      throw StateError(
        ref.read(printerStateProvider).errorMessage ??
            'Label printer connection failed.',
      );
    }
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
      await printerNotifier.connect(receiptPrinter);
      await _waitForPrinterConnection(receiptPrinter.id);
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
    for (var attempt = 0; attempt < 12; attempt++) {
      final connectedPrinter = ref.read(printerStateProvider).connectedDevice;
      if (connectedPrinter?.id == printerId) {
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
        await Navigator.of(context).pushNamed(PrinterConnectScreen.routeName);
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
        const SnackBar(
          content: Text('Voucher reprinted successfully.'),
        ),
      );
      Navigator.of(context).popUntil((route) {
        return route.settings.name == ParcelListScreen.routeName || route.isFirst;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isReprinting = false;
        });
      }
    }
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
        _isLabelPrinting;

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
      isBlocking: (_isReprinting || _isLabelPrinting || printerState.isBusy) &&
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
                        constraints: BoxConstraints(
                          maxWidth: previewWidth,
                        ),
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
                    width: 560,
                    child: ParcelLabelPreview(
                      settings: labelSettingsAsync.value!,
                      name: preview.parcel.receiverName,
                      phone: preview.parcel.receiverPhone,
                      quantity:
                          _labelQuantity ?? preview.parcel.numberOfParcels,
                      includeShadow: false,
                      includeBorder: false,
                      maxWidth: 560,
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
