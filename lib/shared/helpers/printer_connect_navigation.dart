import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/bluetooth_permission_service.dart';
import '../../features/printing/presentation/screens/printer_connect_screen.dart';
import '../../providers/printer_provider.dart';

final bluetoothPermissionServiceProvider = Provider<BluetoothPermissionService>(
  (ref) {
    return const BluetoothPermissionService();
  },
);

Future<void> openPrinterConnectPage(BuildContext context, WidgetRef ref) async {
  final result = await ref
      .read(bluetoothPermissionServiceProvider)
      .ensurePrinterPermissions();

  if (!context.mounted) {
    return;
  }

  if (!result.isGranted) {
    await _showPrinterSetupDialog(
      context,
      title: 'Printer permission လိုအပ်ပါတယ်',
      message:
          result.message ??
          'Printer ရှာဖို့ Bluetooth, Nearby devices နှင့် Location permission လိုအပ်ပါတယ်။',
      primaryLabel: result.requiresSettings ? 'App Settings ဖွင့်မယ်' : 'OK',
      onPrimaryPressed: result.requiresSettings ? openAppSettings : null,
    );
    return;
  }

  final printerCore = ref.read(printerCoreProvider);
  await printerCore.initialize();
  if (!context.mounted) {
    return;
  }

  if (!printerCore.isBluetoothOn) {
    await _showPrinterSetupDialog(
      context,
      title: 'Bluetooth ပိတ်ထားပါတယ်',
      message:
          'Printer ရှာဖို့ Bluetooth ကို အရင်ဖွင့်ထားဖို့လိုပါတယ်။ ဖုန်း Settings သို့မဟုတ် Quick Settings ထဲက Bluetooth ကိုဖွင့်ပြီး ပြန်စမ်းပါ။',
      primaryLabel: 'OK',
    );
    return;
  }

  await Navigator.of(context).pushNamed(PrinterConnectScreen.routeName);
}

Future<void> _showPrinterSetupDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String primaryLabel,
  Future<bool> Function()? onPrimaryPressed,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            await onPrimaryPressed?.call();
          },
          child: Text(primaryLabel),
        ),
      ],
    ),
  );
}
