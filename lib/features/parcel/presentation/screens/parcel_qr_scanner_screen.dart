import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_spacing.dart';

class ParcelQrScannerScreen extends StatefulWidget {
  const ParcelQrScannerScreen({super.key});

  @override
  State<ParcelQrScannerScreen> createState() => _ParcelQrScannerScreenState();
}

class _ParcelQrScannerScreenState extends State<ParcelQrScannerScreen> {
  late final MobileScannerController _controller;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isCompleting) {
      return;
    }

    final rawValue = capture.barcodes
        .map((barcode) => barcode.rawValue ?? barcode.displayValue)
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .firstOrNull;

    if (rawValue == null) {
      return;
    }

    _isCompleting = true;
    await _controller.stop();

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(rawValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Parcel QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, _) {
              final torchState = state.torchState;
              final canToggle = torchState != TorchState.unavailable;
              final isOn = torchState == TorchState.on;

              return IconButton(
                tooltip: isOn ? 'Turn flash off' : 'Turn flash on',
                onPressed: canToggle ? _controller.toggleTorch : null,
                icon: Icon(
                  isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            errorBuilder: (context, error) => _ScannerErrorView(error: error),
          ),
          const _ScannerFrame(),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Voucher QR code ကို camera frame ထဲမှာထားပါ။ ဖတ်ပြီးတာနဲ့ Parcel Detail ကိုဖွင့်မယ်။',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _ScannerErrorView extends StatelessWidget {
  const _ScannerErrorView({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Camera permission မရသေးပါ။ App Settings ထဲမှာ Camera permission ဖွင့်ပေးပါ။',
      MobileScannerErrorCode.unsupported =>
        'ဒီ device မှာ camera scanner ကို မသုံးနိုင်ပါ။',
      _ =>
        'Camera ဖွင့်လို့မရပါ။ Permission နဲ့ camera အသုံးပြုနေမှုကို စစ်ပေးပါ။',
    };

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
