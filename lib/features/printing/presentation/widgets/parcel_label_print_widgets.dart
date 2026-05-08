import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_printer_kit/pos_printer_kit.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/label_strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../providers/printer_provider.dart';
import '../../../../shared/models/label_settings_config.dart';
import '../../../../shared/models/label_printer_selection.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

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
          _PrinterPickerField(
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
                  debugPrint(
                    '[label_print] dialog print requested '
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

class _PrinterPickerField extends StatelessWidget {
  const _PrinterPickerField({
    required this.selectedPrinter,
    required this.printers,
    required this.connectedPrinterId,
    required this.onSelected,
  });

  final PrinterDevice? selectedPrinter;
  final List<PrinterDevice> printers;
  final String? connectedPrinterId;
  final ValueChanged<PrinterDevice> onSelected;

  @override
  Widget build(BuildContext context) {
    final hasPrinters = printers.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: hasPrinters ? () => _showPicker(context) : null,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Printer',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
        ),
        child: Text(
          selectedPrinter == null
              ? (hasPrinters ? 'Choose label printer' : 'Scan printer first')
              : _printerTitle(selectedPrinter!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<PrinterDevice>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            itemCount: printers.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final printer = printers[index];
              final isSelected = printer.id == selectedPrinter?.id;
              final isConnected = printer.id == connectedPrinterId;
              return ListTile(
                title: Text(_printerTitle(printer)),
                subtitle: isConnected ? const Text('Connected') : null,
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded)
                    : null,
                onTap: () => Navigator.of(context).pop(printer),
              );
            },
          ),
        );
      },
    );

    if (selected != null) {
      onSelected(selected);
    }
  }

  String _printerTitle(PrinterDevice printer) {
    return printer.id == connectedPrinterId
        ? '${printer.name} (Connected)'
        : printer.name;
  }
}

class ParcelLabelPreview extends StatelessWidget {
  const ParcelLabelPreview({
    super.key,
    required this.settings,
    required this.name,
    required this.phone,
    required this.address,
    required this.quantity,
    this.includeShadow = true,
    this.includeBorder = true,
    this.maxWidth = 560,
  });

  final LabelSettingsConfig settings;
  final String name;
  final String phone;
  final String address;
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
                      LabelStrings.businessTitle,
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
                      LabelStrings.businessPhone,
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
                    _LabelAddressQuantityRow(
                      address: address,
                      quantity: quantity,
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

class _LabelAddressQuantityRow extends StatelessWidget {
  const _LabelAddressQuantityRow({
    required this.address,
    required this.quantity,
    required this.fontSize,
    required this.labelWidth,
  });

  final String address;
  final int quantity;
  final double fontSize;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            'Address',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
        Expanded(
          child: Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _QuantityBadge(quantity: quantity, fontSize: fontSize),
      ],
    );
  }
}

class _QuantityBadge extends StatelessWidget {
  const _QuantityBadge({required this.quantity, required this.fontSize});

  final int quantity;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final size = (fontSize * 1.8).clamp(32.0, 54.0);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Text(
        quantity.toString(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize * 0.8,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
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
