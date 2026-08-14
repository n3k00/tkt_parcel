import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_printer_kit/pos_printer_kit.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/font_families.dart';
import '../../../../core/constants/label_strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../providers/printer_provider.dart';
import '../../../../shared/models/label_printer_selection.dart';
import '../../../../shared/models/label_settings_config.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import 'label_shared_widgets.dart';

void _logLabelPrint(String message) {
  assert(() {
    debugPrint('[label_print] $message');
    return true;
  }());
}

LabelSettingsConfig _effectiveLabelSettings(LabelSettingsConfig settings) {
  if (settings.labelSize.id != LabelSizePreset.mm80x60.id) {
    return settings;
  }

  return settings.copyWith(
    titleFontSize: settings.titleFontSize.clamp(52.0, 72.0).toDouble(),
    subtitleFontSize: settings.subtitleFontSize.clamp(22.0, 30.0).toDouble(),
    bodyFontSize: settings.bodyFontSize.clamp(30.0, 42.0).toDouble(),
    paddingTop: settings.paddingTop.clamp(0.0, 48.0).toDouble(),
    paddingHorizontal: settings.paddingHorizontal.clamp(0.0, 48.0).toDouble(),
    rowGap: settings.rowGap.clamp(0.0, 48.0).toDouble(),
  );
}

class LabelPrintRequest {
  const LabelPrintRequest({required this.quantity, required this.printer});

  final int quantity;
  final PrinterDevice? printer;
}

class LabelPrintDialog extends ConsumerStatefulWidget {
  const LabelPrintDialog({super.key, required this.initialQuantity});

  final int initialQuantity;

  @override
  ConsumerState<LabelPrintDialog> createState() => _LabelPrintDialogState();
}

class _LabelPrintDialogState extends ConsumerState<LabelPrintDialog> {
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
    final allPrinters = [
      if (printerState.connectedDevice != null) printerState.connectedDevice!,
      for (final printer in printerState.printers)
        if (printer.id != printerState.connectedDevice?.id) printer,
      if (lastLabelPrinter != null &&
          !_containsPrinterId(
            printerState.connectedDevice,
            printerState.printers,
            lastLabelPrinter.id,
          ))
        PrinterDevice(id: lastLabelPrinter.id, name: lastLabelPrinter.name),
    ];
    final selectedPrinter = _selectedPrinterId == null
        ? null
        : _findPrinter(allPrinters, _selectedPrinterId!);

    return AlertDialog(
      title: const Text('Print Label'),
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
          Text(LabelStrings.labelCopiesPrompt, style: AppTextStyles.label),
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
                    LabelPrintRequest(
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

class ParcelLabelPreview extends StatelessWidget {
  const ParcelLabelPreview({
    super.key,
    required this.settings,
    required this.businessPhone,
    required this.name,
    required this.phone,
    required this.address,
    required this.quantity,
    required this.trackingId,
    this.includeShadow = true,
    this.includeBorder = true,
    this.maxWidth,
  });

  final LabelSettingsConfig settings;
  final String businessPhone;
  final String name;
  final String phone;
  final String address;
  final int quantity;
  final String trackingId;
  final bool includeShadow;
  final bool includeBorder;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveSettings = _effectiveLabelSettings(settings);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? effectiveSettings.labelSize.widthPx.toDouble(),
        ),
        child: AspectRatio(
          aspectRatio: effectiveSettings.labelSize.aspectRatio,
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
                effectiveSettings.paddingHorizontal,
                effectiveSettings.paddingTop,
                effectiveSettings.paddingHorizontal,
                24,
              ),
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.black,
                  fontFamily: FontFamilies.myanmar,
                ),
                child:
                    effectiveSettings.labelSize.id == LabelSizePreset.mm80x60.id
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: constraints.maxWidth,
                              child: _LabelPreview80x60(
                                settings: effectiveSettings,
                                businessPhone: businessPhone,
                                name: name,
                                phone: phone,
                                address: address,
                                quantity: quantity,
                                trackingId: trackingId,
                              ),
                            ),
                          );
                        },
                      )
                    : _LabelPreview75x50(
                        settings: effectiveSettings,
                        businessPhone: businessPhone,
                        name: name,
                        phone: phone,
                        address: address,
                        quantity: quantity,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelPreview75x50 extends StatelessWidget {
  const _LabelPreview75x50({
    required this.settings,
    required this.businessPhone,
    required this.name,
    required this.phone,
    required this.address,
    required this.quantity,
  });

  final LabelSettingsConfig settings;
  final String businessPhone;
  final String name;
  final String phone;
  final String address;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LabelHeader(settings: settings, businessPhone: businessPhone),
        SizedBox(height: settings.rowGap),
        const Divider(height: 1, color: Colors.black45),
        SizedBox(height: settings.rowGap),
        _LabelPreviewRow(
          label: 'Name',
          value: name,
          fontSize: settings.bodyFontSize,
          labelWidth: 150,
        ),
        SizedBox(height: settings.rowGap),
        _LabelPreviewRow(
          label: 'Phone',
          value: phone,
          fontSize: settings.bodyFontSize,
          labelWidth: 150,
        ),
        SizedBox(height: settings.rowGap),
        LabelAddressQuantityRow(
          address: address,
          quantity: quantity,
          fontSize: settings.bodyFontSize,
          labelWidth: 150,
        ),
      ],
    );
  }
}

class _LabelPreview80x60 extends StatelessWidget {
  const _LabelPreview80x60({
    required this.settings,
    required this.businessPhone,
    required this.name,
    required this.phone,
    required this.address,
    required this.quantity,
    required this.trackingId,
  });

  final LabelSettingsConfig settings;
  final String businessPhone;
  final String name;
  final String phone;
  final String address;
  final int quantity;
  final String trackingId;

  @override
  Widget build(BuildContext context) {
    final bodyFontSize = settings.bodyFontSize * 1.06;
    final labelWidth = 150.0;
    final qrSize = (settings.labelSize.widthPx * 0.2).clamp(112.0, 130.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LabelHeader(settings: settings, businessPhone: businessPhone),
        SizedBox(height: settings.rowGap * 0.75),
        const Divider(height: 1, color: Colors.black54),
        SizedBox(height: settings.rowGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LabelPreviewRow(
                    label: 'Name',
                    value: name,
                    fontSize: bodyFontSize,
                    labelWidth: labelWidth,
                  ),
                  SizedBox(height: settings.rowGap * 0.8),
                  _LabelPreviewRow(
                    label: 'Phone',
                    value: phone,
                    fontSize: bodyFontSize,
                    labelWidth: labelWidth,
                    valueMaxLines: 2,
                  ),
                  SizedBox(height: settings.rowGap * 0.8),
                  _LabelPreviewRow(
                    label: 'Address',
                    value: address,
                    fontSize: bodyFontSize,
                    labelWidth: labelWidth,
                    valueMaxLines: 1,
                  ),
                  SizedBox(height: settings.rowGap * 0.65),
                  _LabelPreviewRow(
                    label: 'Qty',
                    value: quantity.toString(),
                    fontSize: bodyFontSize,
                    labelWidth: labelWidth,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: qrSize,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrImageView(
                    data: trackingId,
                    size: qrSize,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: qrSize,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        trackingId,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: const TextStyle(
                          fontFamily: FontFamilies.myanmar,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LabelHeader extends StatelessWidget {
  const _LabelHeader({required this.settings, required this.businessPhone});

  final LabelSettingsConfig settings;
  final String businessPhone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LabelStrings.businessTitle,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: FontFamilies.myanmar,
            fontSize: settings.titleFontSize,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        SizedBox(height: settings.rowGap / 2),
        Text(
          businessPhone,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: FontFamilies.myanmar,
            fontSize: settings.subtitleFontSize,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _LabelPreviewRow extends StatelessWidget {
  const _LabelPreviewRow({
    required this.label,
    required this.value,
    required this.fontSize,
    this.labelWidth = 76,
    this.valueMaxLines = 2,
  });

  final String label;
  final String value;
  final double fontSize;
  final double labelWidth;
  final int valueMaxLines;

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
              fontFamily: FontFamilies.myanmar,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: valueMaxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: FontFamilies.myanmar,
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
