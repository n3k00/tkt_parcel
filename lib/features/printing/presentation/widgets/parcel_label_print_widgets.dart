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
  if (settings.labelSize.id == LabelSizePreset.mm75x90.id) {
    final fallbackFieldLabelSize = (settings.bodyFontSize * 0.68)
        .clamp(18.0, 20.0)
        .toDouble();
    return settings.copyWith(
      titleFontSize: settings.titleFontSize.clamp(36.0, 72.0).toDouble(),
      subtitleFontSize: settings.subtitleFontSize.clamp(14.0, 28.0).toDouble(),
      bodyFontSize: settings.bodyFontSize.clamp(20.0, 38.0).toDouble(),
      fieldLabelFontSize:
          (settings.fieldLabelFontSize > 0
                  ? settings.fieldLabelFontSize
                  : fallbackFieldLabelSize)
              .clamp(16.0, 30.0)
              .toDouble(),
      paddingTop: settings.paddingTop.clamp(0.0, 48.0).toDouble(),
      paddingHorizontal: settings.paddingHorizontal.clamp(0.0, 48.0).toDouble(),
      rowGap: settings.rowGap.clamp(0.0, 12.0).toDouble(),
    );
  }
  if (settings.labelSize.id != LabelSizePreset.mm80x60.id) {
    return settings.fieldLabelFontSize > 0
        ? settings
        : settings.copyWith(fieldLabelFontSize: settings.bodyFontSize);
  }

  final fallbackFieldLabelSize = settings.bodyFontSize;
  return settings.copyWith(
    titleFontSize: settings.titleFontSize.clamp(52.0, 72.0).toDouble(),
    subtitleFontSize: settings.subtitleFontSize.clamp(22.0, 30.0).toDouble(),
    bodyFontSize: settings.bodyFontSize.clamp(30.0, 42.0).toDouble(),
    fieldLabelFontSize:
        (settings.fieldLabelFontSize > 0
                ? settings.fieldLabelFontSize
                : fallbackFieldLabelSize)
            .clamp(22.0, 40.0)
            .toDouble(),
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
    this.parcelType = '',
    this.note,
    this.createdAt,
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
  final String parcelType;
  final String? note;
  final DateTime? createdAt;
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
                    effectiveSettings.labelSize.id == LabelSizePreset.mm75x90.id
                    ? LayoutBuilder(
                        builder: (_, _) {
                          final designWidth =
                              effectiveSettings.labelSize.widthPx -
                              (effectiveSettings.paddingHorizontal * 2);
                          final designHeight =
                              effectiveSettings.labelSize.heightPx -
                              effectiveSettings.paddingTop -
                              24;
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: designWidth,
                              height: designHeight,
                              child: _LabelPreview75x90(
                                settings: effectiveSettings,
                                businessPhone: businessPhone,
                                name: name,
                                phone: phone,
                                destination: address,
                                parcelType: parcelType,
                                quantity: quantity,
                                note: note,
                                createdAt: createdAt,
                                trackingId: trackingId,
                              ),
                            ),
                          );
                        },
                      )
                    : effectiveSettings.labelSize.id ==
                          LabelSizePreset.mm80x60.id
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
                        trackingId: trackingId,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelPreview75x90 extends StatelessWidget {
  const _LabelPreview75x90({
    required this.settings,
    required this.businessPhone,
    required this.name,
    required this.phone,
    required this.destination,
    required this.parcelType,
    required this.quantity,
    required this.note,
    required this.createdAt,
    required this.trackingId,
  });

  final LabelSettingsConfig settings;
  final String businessPhone;
  final String name;
  final String phone;
  final String destination;
  final String parcelType;
  final int quantity;
  final String? note;
  final DateTime? createdAt;
  final String trackingId;

  @override
  Widget build(BuildContext context) {
    final bodySize = settings.bodyFontSize;
    final captionSize = settings.fieldLabelFontSize;
    final subtitleSize = settings.subtitleFontSize;
    final compactGap = settings.rowGap;
    final displayNote = note?.trim() ?? '';
    final qrSize = displayNote.isEmpty ? 154.0 : 120.0;
    final trackingTextHeight = bodySize * 0.72 * 1.2;
    final footerHeight = qrSize + 5 + trackingTextHeight + 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 82,
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                LabelStrings.businessTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: FontFamilies.myanmar,
                  fontSize: settings.titleFontSize,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: compactGap * 0.35),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 30,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    businessPhone,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: FontFamilies.myanmar,
                      fontSize: subtitleSize,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 30,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Date: ${_formatLabelDate(createdAt)}',
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: FontFamilies.myanmar,
                      fontSize: subtitleSize,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compactGap),
        const Divider(height: 1, thickness: 1.5, color: Colors.black),
        SizedBox(height: compactGap),
        _ShippingLabelRow(
          label: 'Receiver',
          value: name,
          captionFontSize: captionSize,
          valueFontSize: bodySize,
          valueMaxLines: 1,
        ),
        SizedBox(height: compactGap * 0.7),
        _ShippingLabelRow(
          label: 'Phone',
          value: phone,
          captionFontSize: captionSize,
          valueFontSize: bodySize,
          valueMaxLines: 1,
        ),
        SizedBox(height: compactGap * 0.7),
        _ShippingLabelRow(
          label: 'To',
          value: destination,
          captionFontSize: captionSize,
          valueFontSize: bodySize,
          valueMaxLines: 1,
        ),
        SizedBox(height: compactGap),
        const Divider(height: 1, thickness: 1.5, color: Colors.black),
        SizedBox(height: compactGap),
        _ShippingLabelRow(
          label: 'Parcel Type',
          value: _limitedParcelType(parcelType),
          captionFontSize: captionSize,
          valueFontSize: bodySize,
          valueMaxLines: 2,
        ),
        SizedBox(height: compactGap * 0.7),
        _ShippingLabelRow(
          label: 'QTY',
          value: quantity.toString(),
          captionFontSize: captionSize,
          valueFontSize: bodySize,
          valueMaxLines: 1,
        ),
        if (displayNote.isNotEmpty) ...[
          SizedBox(height: compactGap),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 7),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOTE',
                  style: TextStyle(
                    fontFamily: FontFamilies.myanmar,
                    fontSize: captionSize,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayNote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: FontFamilies.myanmar,
                    fontSize: bodySize * 0.82,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: compactGap),
        const Spacer(),
        SizedBox(
          height: footerHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  data: trackingId,
                  size: qrSize,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    trackingId,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: FontFamilies.myanmar,
                      fontSize: bodySize * 0.72,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _formatLabelDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.year}';
  }

  static String _limitedParcelType(String value) {
    const limit = 36;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '-';
    }
    final visibleCharacters = trimmed.characters;
    if (visibleCharacters.length <= limit) {
      return trimmed;
    }
    return '${visibleCharacters.take(limit)}…';
  }
}

class _ShippingLabelRow extends StatelessWidget {
  const _ShippingLabelRow({
    required this.label,
    required this.value,
    required this.captionFontSize,
    required this.valueFontSize,
    required this.valueMaxLines,
  });

  final String label;
  final String value;
  final double captionFontSize;
  final double valueFontSize;
  final int valueMaxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 145,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontFamily: FontFamilies.myanmar,
              fontSize: captionFontSize,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '-' : value,
            maxLines: valueMaxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: FontFamilies.myanmar,
              fontSize: valueFontSize,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ],
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
    final qrSize = (settings.labelSize.widthPx * 0.17).clamp(92.0, 108.0);
    final labelWidth = 124.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LabelHeader(settings: settings, businessPhone: businessPhone),
        SizedBox(height: settings.rowGap),
        const Divider(height: 1, color: Colors.black45),
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
                    fontSize: settings.bodyFontSize,
                    labelFontSize: settings.fieldLabelFontSize,
                    labelWidth: labelWidth,
                    valueMaxLines: 1,
                  ),
                  SizedBox(height: settings.rowGap * 0.75),
                  _LabelPreviewRow(
                    label: 'Phone',
                    value: phone,
                    fontSize: settings.bodyFontSize,
                    labelFontSize: settings.fieldLabelFontSize,
                    labelWidth: labelWidth,
                    valueMaxLines: 1,
                  ),
                  SizedBox(height: settings.rowGap * 0.75),
                  _LabelPreviewRow(
                    label: 'Address',
                    value: address,
                    fontSize: settings.bodyFontSize,
                    labelFontSize: settings.fieldLabelFontSize,
                    labelWidth: labelWidth,
                    valueMaxLines: 1,
                  ),
                  SizedBox(height: settings.rowGap * 0.75),
                  _LabelPreviewRow(
                    label: 'Qty',
                    value: quantity.toString(),
                    fontSize: settings.bodyFontSize,
                    labelFontSize: settings.fieldLabelFontSize,
                    labelWidth: labelWidth,
                    valueMaxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            QrImageView(
              data: trackingId,
              size: qrSize,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
            ),
          ],
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
                    labelFontSize: settings.fieldLabelFontSize,
                    labelWidth: labelWidth,
                  ),
                  SizedBox(height: settings.rowGap * 0.8),
                  _LabelPreviewRow(
                    label: 'Phone',
                    value: phone,
                    fontSize: bodyFontSize,
                    labelFontSize: settings.fieldLabelFontSize,
                    labelWidth: labelWidth,
                    valueMaxLines: 2,
                  ),
                  SizedBox(height: settings.rowGap * 0.8),
                  _LabelPreviewRow(
                    label: 'Address',
                    value: address,
                    fontSize: bodyFontSize,
                    labelFontSize: settings.fieldLabelFontSize,
                    labelWidth: labelWidth,
                    valueMaxLines: 1,
                  ),
                  SizedBox(height: settings.rowGap * 0.65),
                  _LabelPreviewRow(
                    label: 'Qty',
                    value: quantity.toString(),
                    fontSize: bodyFontSize,
                    labelFontSize: settings.fieldLabelFontSize,
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
    this.labelFontSize,
    this.labelWidth = 76,
    this.valueMaxLines = 2,
  });

  final String label;
  final String value;
  final double fontSize;
  final double? labelFontSize;
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
              fontSize: labelFontSize ?? fontSize,
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
