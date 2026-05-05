import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_printer_kit/pos_printer_kit.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/layout/app_responsive.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../providers/printer_provider.dart';
import '../../../../shared/models/label_settings_config.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../printing/presentation/screens/printer_connect_screen.dart';
import '../constants/label_settings_dimens.dart';
import '../providers/settings_provider.dart';

class LabelSettingsScreen extends ConsumerStatefulWidget {
  const LabelSettingsScreen({super.key});

  static const routeName = '/settings/label';

  @override
  ConsumerState<LabelSettingsScreen> createState() =>
      _LabelSettingsScreenState();
}

class _LabelSettingsScreenState extends ConsumerState<LabelSettingsScreen> {
  final GlobalKey _labelPrintKey = GlobalKey();
  LabelSettingsConfig? _draft;
  int _testQuantity = 3;
  bool _isTestPrinting = false;
  bool _isCapturingLabel = false;
  bool _shouldRestoreReceiptPrinter = false;

  Future<void> _handleTestPrint() async {
    if (_isTestPrinting) {
      return;
    }

    final request = await showDialog<_LabelTestPrintRequest>(
      context: context,
      builder: (_) => _LabelTestPrintDialog(initialQuantity: _testQuantity),
    );
    if (request == null) {
      return;
    }
    debugPrint(
      '[label_print] request received printer='
      '${request.printer?.name ?? 'none'} qty=${request.quantity}',
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

      debugPrint('[label_print] capture started');
      final imageBytes = await ref
          .read(printServiceProvider)
          .captureWidgetAsPng(_labelPrintKey, pixelRatio: 1)
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () {
              throw StateError('Label image capture timed out.');
            },
          );
      debugPrint('[label_print] captured ${imageBytes.length} bytes');

      if (!mounted) {
        return;
      }

      setState(() {
        _isCapturingLabel = false;
        _isTestPrinting = true;
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
      debugPrint(
        '[label_print] before tspl print '
        'connected=${ref.read(printerStateProvider).connectedPrinterName} '
        'busy=${ref.read(printerStateProvider).isBusy} idle=$isIdle',
      );
      if (!isIdle) {
        throw StateError('Printer is busy. Please try again.');
      }

      final success = await printerNotifier.printTsplLabelImage(
        imageBytes,
        copies: request.quantity,
      );
      debugPrint('[label_print] tspl print result=$success');

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
    _receiptPrinterBeforeLabelPrint = ref.read(printerStateProvider).connectedDevice;
    _shouldRestoreReceiptPrinter = false;

    if (_receiptPrinterBeforeLabelPrint?.id == labelPrinter.id) {
      debugPrint(
        '[label_print] selected printer is already connected: '
        '${labelPrinter.name}',
      );
      return;
    }

    if (_receiptPrinterBeforeLabelPrint != null) {
      _shouldRestoreReceiptPrinter = true;
      debugPrint(
        '[label_print] disconnecting receipt printer: '
        '${_receiptPrinterBeforeLabelPrint!.name}',
      );
      await printerNotifier.disconnect();
    }

    debugPrint('[label_print] connecting label printer: ${labelPrinter.name}');
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
      debugPrint(
        '[label_print] restoring receipt printer: ${receiptPrinter.name}',
      );
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

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(labelSettingsProvider);
    final printerState = ref.watch(printerStateProvider);
    final isProcessing = _isTestPrinting || printerState.isBusy;

    return AppScaffold(
      title: AppStrings.labelSettingsTitle,
      isBlocking: isProcessing && !_isCapturingLabel,
      body: settingsAsync.when(
        data: (settings) {
          _draft ??= settings;
          final draft = _draft!;
          final contentWidth = AppResponsive.centeredContentWidth(
            context,
            horizontalPadding: AppSpacing.lg,
          );

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
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: 560,
                              child: _LabelPreview(
                                settings: draft,
                                quantity: _testQuantity,
                                maxWidth: 560,
                              ),
                            ),
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
                                _draft = draft.copyWith(subtitleFontSize: value);
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
                              min: LabelSettingsDimens.topPaddingMin,
                              max: LabelSettingsDimens.topPaddingMax,
                              onChanged: (value) => setState(() {
                                _draft = draft.copyWith(paddingTop: value);
                              }),
                            ),
                            _SliderField(
                              label: AppStrings.horizontalLabel,
                              value: draft.paddingHorizontal,
                              min: LabelSettingsDimens.horizontalPaddingMin,
                              max: LabelSettingsDimens.horizontalPaddingMax,
                              onChanged: (value) => setState(() {
                                _draft = draft.copyWith(
                                  paddingHorizontal: value,
                                );
                              }),
                            ),
                            _SliderField(
                              label: AppStrings.rowGapLabel,
                              value: draft.rowGap,
                              min: LabelSettingsDimens.rowGapMin,
                              max: LabelSettingsDimens.rowGapMax,
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
                          onPressed: isProcessing ? null : _handleTestPrint,
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
                                      .saveSettings(draft);
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
              Positioned(
                left: -10000,
                top: 0,
                child: RepaintBoundary(
                  key: _labelPrintKey,
                  child: SizedBox(
                    width: 560,
                    child: _LabelPreview(
                      settings: draft,
                      quantity: _testQuantity,
                      includeShadow: false,
                      includeBorder: false,
                      maxWidth: 560,
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

class _LabelPreview extends StatelessWidget {
  const _LabelPreview({
    required this.settings,
    required this.quantity,
    this.includeShadow = true,
    this.includeBorder = true,
    this.maxWidth = 560,
  });

  final LabelSettingsConfig settings;
  final int quantity;
  final bool includeShadow;
  final bool includeBorder;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: AspectRatio(
          aspectRatio: 70 / 50,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: includeBorder ? Border.all(color: Colors.black12) : null,
              boxShadow: includeShadow
                  ? const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                settings.paddingHorizontal,
                settings.paddingTop,
                settings.paddingHorizontal,
                24,
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.black),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'သိင်္ခသူ',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: settings.titleFontSize,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: settings.rowGap / 2),
                    Text(
                      '09-250787547, 09253003004',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: settings.subtitleFontSize,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: settings.rowGap),
                    const Divider(height: 1, color: Colors.black45),
                    SizedBox(height: settings.rowGap),
                    _LabelPreviewRow(
                      label: 'Name',
                      value: 'ကိုကျော်',
                      fontSize: settings.bodyFontSize,
                      labelWidth: 150,
                    ),
                    SizedBox(height: settings.rowGap),
                    _LabelPreviewRow(
                      label: 'Phone',
                      value: '09794249873',
                      fontSize: settings.bodyFontSize,
                      labelWidth: 150,
                    ),
                    SizedBox(height: settings.rowGap),
                    _LabelPreviewRow(
                      label: 'Qty',
                      value: quantity.toString(),
                      fontSize: settings.bodyFontSize,
                      labelWidth: 150,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelTestPrintRequest {
  const _LabelTestPrintRequest({
    required this.quantity,
    required this.printer,
  });

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
      _selectedPrinterId = printerState.connectedDevice?.id;
      if (printerState.printers.isEmpty) {
        ref.read(printerStateProvider.notifier).startScan();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final printerState = ref.watch(printerStateProvider);
    final printers = printerState.printers;
    final allPrinters = [
      if (printerState.connectedDevice != null) printerState.connectedDevice!,
      for (final printer in printers)
        if (printer.id != printerState.connectedDevice?.id) printer,
    ];
    final selectedPrinter = _selectedPrinterId == null
        ? (printerState.connectedDevice ??
              (allPrinters.isEmpty ? null : allPrinters.first))
        : _findPrinter(allPrinters, _selectedPrinterId!) ??
              printerState.connectedDevice ??
              (allPrinters.isEmpty ? null : allPrinters.first);

    return AlertDialog(
      title: const Text('Test Print Label'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(
              '${selectedPrinter?.id ?? 'none'}-${allPrinters.length}',
            ),
            initialValue: selectedPrinter?.id,
            decoration: const InputDecoration(
              labelText: 'Printer',
              border: OutlineInputBorder(),
            ),
            items: allPrinters
                .map(
                  (printer) => DropdownMenuItem(
                    value: printer.id,
                    child: Text(
                      printer.id == printerState.connectedDevice?.id
                          ? '${printer.name} (Connected)'
                          : printer.name,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedPrinterId = value;
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: printerState.isScanning
                ? null
                : () => ref.read(printerStateProvider.notifier).startScan(),
            icon: const Icon(Icons.bluetooth_searching_rounded),
            label: Text(printerState.isScanning ? 'Scanning...' : 'Scan Printer'),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('ပစ္စည်းအရေအတွက်', style: AppTextStyles.label),
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
              : () {
                  debugPrint(
                    '[label_print] dialog print requested '
                    'printer=${selectedPrinter.name} qty=$_quantity',
                  );
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
}

class _LabelPreviewRow extends StatelessWidget {
  const _LabelPreviewRow({
    required this.label,
    required this.value,
    required this.fontSize,
    this.labelWidth = 76,
  });

  final String label;
  final String value;
  final double fontSize;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
  });

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
