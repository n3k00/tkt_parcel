import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_printer_kit/pos_printer_kit.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/label_strings.dart';
import '../../../../core/layout/app_responsive.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../providers/printer_provider.dart';
import '../../../../shared/helpers/printer_connect_navigation.dart';
import '../../../../shared/models/label_printer_selection.dart';
import '../../../../shared/models/label_settings_config.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../printing/presentation/widgets/label_shared_widgets.dart';
import '../../../printing/presentation/widgets/parcel_label_print_widgets.dart';
import '../../../auth/providers/auth_provider.dart';
import '../constants/label_settings_dimens.dart';
import '../providers/settings_provider.dart';

void _logLabelPrint(String message) {
  assert(() {
    debugPrint('[label_print] $message');
    return true;
  }());
}

Duration _labelPrintTimeout(int copies) {
  return Duration(seconds: 8 + copies.clamp(1, 20));
}

class LabelSettingsScreen extends ConsumerStatefulWidget {
  const LabelSettingsScreen({super.key});

  static const routeName = '/settings/label';

  @override
  ConsumerState<LabelSettingsScreen> createState() =>
      _LabelSettingsScreenState();
}

class _LabelSettingsScreenState extends ConsumerState<LabelSettingsScreen> {
  static const _printerSwitchDelay = Duration(milliseconds: 650);

  final GlobalKey _labelPrintKey = GlobalKey();
  LabelSettingsConfig? _draft;
  int _testQuantity = 3;
  bool _isTestPrinting = false;
  bool _isCapturingLabel = false;
  bool _shouldRestoreReceiptPrinter = false;

  double _topPaddingMin(LabelSizePreset labelSize) {
    return labelSize.id == LabelSizePreset.mm80x60.id
        ? LabelSettingsDimens.topPaddingMin80x60
        : LabelSettingsDimens.topPaddingMin;
  }

  double _topPaddingMax(LabelSizePreset labelSize) {
    return labelSize.id == LabelSizePreset.mm80x60.id
        ? LabelSettingsDimens.topPaddingMax80x60
        : LabelSettingsDimens.topPaddingMax;
  }

  double _horizontalPaddingMin(LabelSizePreset labelSize) {
    return labelSize.id == LabelSizePreset.mm80x60.id
        ? LabelSettingsDimens.horizontalPaddingMin80x60
        : LabelSettingsDimens.horizontalPaddingMin;
  }

  double _horizontalPaddingMax(LabelSizePreset labelSize) {
    return labelSize.id == LabelSizePreset.mm80x60.id
        ? LabelSettingsDimens.horizontalPaddingMax80x60
        : LabelSettingsDimens.horizontalPaddingMax;
  }

  double _rowGapMax(LabelSizePreset labelSize) {
    return labelSize.id == LabelSizePreset.mm80x60.id
        ? LabelSettingsDimens.rowGapMax80x60
        : LabelSettingsDimens.rowGapMax;
  }

  double _rowGapMin(LabelSizePreset labelSize) {
    return labelSize.id == LabelSizePreset.mm80x60.id
        ? LabelSettingsDimens.rowGapMin80x60
        : LabelSettingsDimens.rowGapMin;
  }

  LabelSettingsConfig _normalizeDraft(LabelSettingsConfig config) {
    return config.copyWith(
      paddingTop: config.paddingTop
          .clamp(
            _topPaddingMin(config.labelSize),
            _topPaddingMax(config.labelSize),
          )
          .toDouble(),
      paddingHorizontal: config.paddingHorizontal
          .clamp(
            _horizontalPaddingMin(config.labelSize),
            _horizontalPaddingMax(config.labelSize),
          )
          .toDouble(),
      rowGap: config.rowGap
          .clamp(_rowGapMin(config.labelSize), _rowGapMax(config.labelSize))
          .toDouble(),
    );
  }

  Future<void> _handleTestPrint() async {
    if (_isTestPrinting) {
      return;
    }
    if (!ref.read(settingsSetupProvider).hasValue) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voucher header is still loading.')),
      );
      return;
    }

    final request = await showDialog<_LabelTestPrintRequest>(
      context: context,
      builder: (_) => _LabelTestPrintDialog(initialQuantity: _testQuantity),
    );
    if (request == null) {
      return;
    }
    final labelSize = _draft!.labelSize;
    _logLabelPrint(
      'request received printer='
      '${request.printer?.name ?? 'none'} qty=${request.quantity} '
      'size=${labelSize.id}',
    );

    setState(() {
      _testQuantity = request.quantity;
      _isCapturingLabel = true;
    });

    try {
      await WidgetsBinding.instance.endOfFrame;

      if (!mounted) {
        return;
      }

      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 120));

      _logLabelPrint('capture started');
      final imageBytes = await ref
          .read(printServiceProvider)
          .captureWidgetAsPng(_labelPrintKey, pixelRatio: 1)
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () {
              throw StateError('Label image capture timed out.');
            },
          );
      _logLabelPrint('captured ${imageBytes.length} bytes');

      if (!mounted) {
        return;
      }

      setState(() {
        _isCapturingLabel = false;
        _isTestPrinting = true;
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
        'busy=${ref.read(printerStateProvider).isBusy} idle=$isIdle',
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
                ? 'Test label printed successfully.'
                : ref.read(printerStateProvider).errorMessage ??
                      'Test label print failed.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test label print failed: $error')),
        );
      }
    } finally {
      await _restoreReceiptPrinter();
      if (mounted) {
        setState(() {
          _isTestPrinting = false;
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
      _logLabelPrint(
        'selected printer is already connected: ${labelPrinter.name}',
      );
      await _waitForPrinterIdle();
      await Future<void>.delayed(_printerSwitchDelay);
      return;
    }

    if (_receiptPrinterBeforeLabelPrint != null) {
      _shouldRestoreReceiptPrinter = true;
      _logLabelPrint(
        'disconnecting receipt printer: '
        '${_receiptPrinterBeforeLabelPrint!.name}',
      );
      await printerNotifier.disconnect();
      await _waitForPrinterDisconnected(_receiptPrinterBeforeLabelPrint!.id);
      await Future<void>.delayed(_printerSwitchDelay);
    }

    _logLabelPrint('connecting label printer: ${labelPrinter.name}');
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
      _logLabelPrint('restoring receipt printer: ${receiptPrinter.name}');
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

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(labelSettingsProvider);
    final setupAsync = ref.watch(settingsSetupProvider);
    final staffProfileAsync = ref.watch(staffProfileProvider);
    final printerState = ref.watch(printerStateProvider);
    final isProcessing = _isTestPrinting || printerState.isBusy;

    return AppScaffold(
      title: AppStrings.labelSettingsTitle,
      isBlocking: isProcessing && !_isCapturingLabel,
      body: settingsAsync.when(
        data: (settings) {
          _draft ??= settings;
          final draft = _normalizeDraft(_draft!);
          final contentWidth = AppResponsive.centeredContentWidth(
            context,
            horizontalPadding: AppSpacing.lg,
          );
          final branchPhone =
              staffProfileAsync.asData?.value?.branchPhoneNumbers;
          final localPhone = setupAsync.asData?.value.businessPhone;
          final businessPhone = branchPhone?.trim().isNotEmpty == true
              ? branchPhone!.trim()
              : localPhone;
          final isSetupReady = businessPhone != null;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: contentWidth,
                  child: ListView(
                    padding: AppSpacing.screenPadding,
                    children: [
                      _SettingsSection(
                        title: AppStrings.livePreviewTitle,
                        child: Center(
                          child: isSetupReady
                              ? FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    width: draft.labelSize.widthPx.toDouble(),
                                    child: ParcelLabelPreview(
                                      settings: draft,
                                      businessPhone: businessPhone,
                                      name: LabelStrings.sampleReceiverName,
                                      phone: LabelStrings.sampleReceiverPhone,
                                      address: LabelStrings.sampleAddress,
                                      quantity: _testQuantity,
                                      trackingId: LabelStrings.sampleTrackingId,
                                      maxWidth: draft.labelSize.widthPx
                                          .toDouble(),
                                    ),
                                  ),
                                )
                              : const Padding(
                                  padding: EdgeInsets.all(AppSpacing.lg),
                                  child: AppLoading(),
                                ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SettingsSection(
                        title: AppStrings.labelSizeLabel,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SegmentedButton<LabelSizePreset>(
                            segments: [
                              for (final option in LabelSizePreset.values)
                                ButtonSegment<LabelSizePreset>(
                                  value: option,
                                  label: Text(option.label),
                                ),
                            ],
                            selected: {draft.labelSize},
                            onSelectionChanged: (selected) {
                              setState(() {
                                _draft = _normalizeDraft(
                                  draft.copyWith(labelSize: selected.first),
                                );
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SettingsSection(
                        title: AppStrings.headerFontSizeTitle,
                        child: Column(
                          children: [
                            _SliderField(
                              label: AppStrings.titleLabel,
                              value: draft.titleFontSize,
                              min: LabelSettingsDimens.titleFontMin,
                              max: LabelSettingsDimens.titleFontMax,
                              onChanged: (value) => setState(() {
                                _draft = draft.copyWith(titleFontSize: value);
                              }),
                            ),
                            _SliderField(
                              label: AppStrings.subtitleLabel,
                              value: draft.subtitleFontSize,
                              min: LabelSettingsDimens.subtitleFontMin,
                              max: LabelSettingsDimens.subtitleFontMax,
                              onChanged: (value) => setState(() {
                                _draft = draft.copyWith(
                                  subtitleFontSize: value,
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SettingsSection(
                        title: AppStrings.bodyFontSizeTitle,
                        child: _SliderField(
                          label: AppStrings.bodyLabel,
                          value: draft.bodyFontSize,
                          min: LabelSettingsDimens.bodyFontMin,
                          max: LabelSettingsDimens.bodyFontMax,
                          onChanged: (value) => setState(() {
                            _draft = draft.copyWith(bodyFontSize: value);
                          }),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SettingsSection(
                        title: AppStrings.receiptPaddingTitle,
                        child: Column(
                          children: [
                            _SliderField(
                              label: AppStrings.topLabel,
                              value: draft.paddingTop,
                              min: _topPaddingMin(draft.labelSize),
                              max: _topPaddingMax(draft.labelSize),
                              onChanged: (value) => setState(() {
                                _draft = draft.copyWith(paddingTop: value);
                              }),
                            ),
                            _SliderField(
                              label: AppStrings.horizontalLabel,
                              value: draft.paddingHorizontal,
                              min: _horizontalPaddingMin(draft.labelSize),
                              max: _horizontalPaddingMax(draft.labelSize),
                              onChanged: (value) => setState(() {
                                _draft = draft.copyWith(
                                  paddingHorizontal: value,
                                );
                              }),
                            ),
                            _SliderField(
                              label: AppStrings.rowGapLabel,
                              value: draft.rowGap,
                              min: _rowGapMin(draft.labelSize),
                              max: _rowGapMax(draft.labelSize),
                              onChanged: (value) => setState(() {
                                _draft = draft.copyWith(rowGap: value);
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isProcessing || !isSetupReady
                              ? null
                              : _handleTestPrint,
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Test Print'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isProcessing
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  await ref
                                      .read(labelSettingsProvider.notifier)
                                      .saveSettings(_normalizeDraft(draft));
                                  if (!mounted) {
                                    return;
                                  }
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        AppStrings.labelSettingsSaved,
                                      ),
                                    ),
                                  );
                                },
                          child: const Text(AppStrings.saveLabelSettings),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isSetupReady)
                Positioned(
                  left: -10000,
                  top: 0,
                  child: RepaintBoundary(
                    key: _labelPrintKey,
                    child: SizedBox(
                      width: draft.labelSize.widthPx.toDouble(),
                      child: ParcelLabelPreview(
                        settings: draft,
                        businessPhone: businessPhone,
                        name: LabelStrings.sampleReceiverName,
                        phone: LabelStrings.sampleReceiverPhone,
                        address: LabelStrings.sampleAddress,
                        quantity: _testQuantity,
                        trackingId: LabelStrings.sampleTrackingId,
                        includeShadow: false,
                        includeBorder: false,
                        maxWidth: draft.labelSize.widthPx.toDouble(),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: AppLoading.new,
        error: (error, _) => AppErrorView(message: error.toString()),
      ),
    );
  }
}

class _LabelTestPrintRequest {
  const _LabelTestPrintRequest({required this.quantity, required this.printer});

  final int quantity;
  final PrinterDevice? printer;
}

class _LabelTestPrintDialog extends ConsumerStatefulWidget {
  const _LabelTestPrintDialog({required this.initialQuantity});

  final int initialQuantity;

  @override
  ConsumerState<_LabelTestPrintDialog> createState() =>
      _LabelTestPrintDialogState();
}

class _LabelTestPrintDialogState extends ConsumerState<_LabelTestPrintDialog> {
  late int _quantity;
  String? _selectedPrinterId;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity.clamp(1, 999).toInt();
    Future.microtask(() {
      final printerState = ref.read(printerStateProvider);
      _selectedPrinterId = ref.read(lastLabelPrinterProvider).asData?.value?.id;
      if (printerState.printers.isEmpty) {
        ref.read(printerStateProvider.notifier).startScan();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final printerState = ref.watch(printerStateProvider);
    final lastLabelPrinter = ref.watch(lastLabelPrinterProvider).asData?.value;
    final printers = printerState.printers;
    final allPrinters = [
      if (printerState.connectedDevice != null) printerState.connectedDevice!,
      for (final printer in printers)
        if (printer.id != printerState.connectedDevice?.id) printer,
      if (lastLabelPrinter != null &&
          !_containsPrinterId(
            printerState.connectedDevice,
            printers,
            lastLabelPrinter.id,
          ))
        PrinterDevice(id: lastLabelPrinter.id, name: lastLabelPrinter.name),
    ];
    final selectedPrinter = _selectedPrinterId == null
        ? null
        : _findPrinter(allPrinters, _selectedPrinterId!);

    return AlertDialog(
      title: const Text('Test Print Label'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabelPrinterPickerField(
            selectedPrinter: selectedPrinter,
            printers: allPrinters,
            connectedPrinterId: printerState.connectedDevice?.id,
            onSelected: (printer) {
              setState(() {
                _selectedPrinterId = printer.id;
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: printerState.isScanning
                ? null
                : () => ref.read(printerStateProvider.notifier).startScan(),
            icon: const Icon(Icons.bluetooth_searching_rounded),
            label: Text(
              printerState.isScanning ? 'Scanning...' : 'Scan Printer',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(LabelStrings.quantityPrompt, style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              IconButton.outlined(
                onPressed: _quantity <= 1
                    ? null
                    : () => setState(() {
                        _quantity--;
                      }),
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: TextFormField(
                  key: ValueKey(_quantity),
                  initialValue: _quantity.toString(),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) {
                      _quantity = parsed.clamp(1, 999).toInt();
                    }
                  },
                ),
              ),
              IconButton.outlined(
                onPressed: _quantity >= 999
                    ? null
                    : () => setState(() {
                        _quantity++;
                      }),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancelAction),
        ),
        FilledButton(
          onPressed: selectedPrinter == null
              ? null
              : () async {
                  _logLabelPrint(
                    'dialog print requested '
                    'printer=${selectedPrinter.name} qty=$_quantity',
                  );
                  await saveLastLabelPrinter(
                    ref,
                    LabelPrinterSelection(
                      id: selectedPrinter.id,
                      name: selectedPrinter.name,
                    ),
                  );
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pop(
                    _LabelTestPrintRequest(
                      quantity: _quantity.clamp(1, 999).toInt(),
                      printer: selectedPrinter,
                    ),
                  );
                },
          child: const Text('Print'),
        ),
      ],
    );
  }

  PrinterDevice? _findPrinter(List<PrinterDevice> printers, String id) {
    for (final printer in printers) {
      if (printer.id == id) {
        return printer;
      }
    }
    return null;
  }

  bool _containsPrinterId(
    PrinterDevice? connectedDevice,
    List<PrinterDevice> printers,
    String id,
  ) {
    if (connectedDevice?.id == id) {
      return true;
    }
    for (final printer in printers) {
      if (printer.id == id) {
        return true;
      }
    }
    return false;
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(min, max).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppTextStyles.label)),
              Text(clampedValue.toStringAsFixed(0), style: AppTextStyles.body),
            ],
          ),
          Slider(
            value: clampedValue,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
