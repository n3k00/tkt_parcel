import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class BluetoothPermissionResult {
  const BluetoothPermissionResult({
    required this.isGranted,
    this.message,
    this.requiresSettings = false,
  });

  final bool isGranted;
  final String? message;
  final bool requiresSettings;
}

class BluetoothPermissionService {
  const BluetoothPermissionService();

  Future<BluetoothPermissionResult> ensurePrinterPermissions() async {
    if (!Platform.isAndroid) {
      return const BluetoothPermissionResult(isGranted: true);
    }

    final permissions = <Permission>[
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ];
    final currentStatuses = <Permission, PermissionStatus>{};
    for (final permission in permissions) {
      currentStatuses[permission] = await permission.status;
    }

    final missingPermissions = currentStatuses.entries
        .where((entry) => !entry.value.isGranted)
        .map((entry) => entry.key)
        .toList();

    if (missingPermissions.isEmpty) {
      return const BluetoothPermissionResult(isGranted: true);
    }

    final requestedStatuses = await missingPermissions.request();
    final mergedStatuses = {...currentStatuses, ...requestedStatuses};

    final allGranted = mergedStatuses.values.every(
      (status) => status.isGranted,
    );
    if (allGranted) {
      return const BluetoothPermissionResult(isGranted: true);
    }

    final permanentlyDenied = mergedStatuses.values.any(
      (status) => status.isPermanentlyDenied || status.isRestricted,
    );

    return BluetoothPermissionResult(
      isGranted: false,
      requiresSettings: permanentlyDenied,
      message: permanentlyDenied
          ? 'Printer ရှာဖို့ permission ပိတ်ထားပါတယ်။ App Settings ထဲမှာ Nearby devices / Bluetooth နှင့် Location permission ကို Allow လုပ်ပေးပါ။'
          : 'Printer ရှာဖို့ Nearby devices / Bluetooth နှင့် Location permission ကို Allow လုပ်ပေးပါ။',
    );
  }
}
