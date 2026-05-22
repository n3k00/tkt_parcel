import 'package:flutter/material.dart';
import 'package:pos_printer_kit/pos_printer_kit.dart';

import '../../../../core/theme/app_spacing.dart';

class LabelPrinterPickerField extends StatelessWidget {
  const LabelPrinterPickerField({
    super.key,
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

class LabelAddressQuantityRow extends StatelessWidget {
  const LabelAddressQuantityRow({
    super.key,
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
