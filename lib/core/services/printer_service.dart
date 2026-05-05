import 'dart:typed_data';

import 'package:pos_printer_kit/pos_printer_kit.dart';

class PrinterService {
  PrinterService(this.core);

  final PrinterCore core;

  Stream<PrinterConnectionState> get onStateChanged => core.onStateChanged;

  Stream<PrinterPrintProgress> get onPrintProgress => core.onPrintProgress;

  Stream<PrinterOperationException> get onError => core.onError;

  Future<void> startScan() => core.startScan();

  Future<void> stopScan() => core.stopScan();

  Future<void> connect(PrinterDevice device) => core.connect(device);

  Future<void> disconnect() => core.disconnect();

  Future<bool> printImage(
    Uint8List imageBytes, {
    PrinterPrintConfig config = const PrinterPrintConfig(),
  }) {
    return core.printImage(imageBytes, config: config);
  }

  Future<bool> printTsplLabelImage(
    Uint8List imageBytes, {
    int widthPx = 560,
    int heightPx = 400,
    double labelWidthMm = 70,
    double labelHeightMm = 50,
    double gapMm = 2,
    int xOffsetPx = 0,
    int yOffsetPx = 0,
    int copies = 1,
    int threshold = 170,
  }) {
    return core.printTsplLabelImage(
      imageBytes,
      widthPx: widthPx,
      heightPx: heightPx,
      labelWidthMm: labelWidthMm,
      labelHeightMm: labelHeightMm,
      gapMm: gapMm,
      xOffsetPx: xOffsetPx,
      yOffsetPx: yOffsetPx,
      copies: copies,
      threshold: threshold,
      invertBitmap: true,
      direction: 0,
      mirror: false,
      tear: false,
      homeBeforePrint: false,
      calibrateGapBeforePrint: false,
      feedToGapAfterPrint: false,
    );
  }

  Future<bool> testPrint() => core.printDemoImage();

  bool get hasConnectedPrinter => core.hasConnectedPrinter;
}
