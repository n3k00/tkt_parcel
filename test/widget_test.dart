import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_printer_kit/pos_printer_kit.dart';
import 'package:tkt_parcel/core/theme/app_theme.dart';
import 'package:tkt_parcel/features/parcel/presentation/providers/parcel_list_provider.dart';
import 'package:tkt_parcel/features/parcel/presentation/screens/parcel_list_screen.dart';
import 'package:tkt_parcel/features/printing/presentation/screens/printer_connect_screen.dart';
import 'package:tkt_parcel/providers/printer_provider.dart';

class _FakePrinterNotifier extends PrinterNotifier {
  _FakePrinterNotifier(this._state);

  final PrinterState _state;

  @override
  PrinterState build() => _state;
}

Widget _buildTestApp({
  required PrinterState printerState,
}) {
  return ProviderScope(
    overrides: [
      parcelListProvider.overrideWith((ref) => Stream.value(const [])),
      printerStateProvider.overrideWith(() => _FakePrinterNotifier(printerState)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      routes: {
        PrinterConnectScreen.routeName: (_) => const Scaffold(
              body: Text('Printer Connect Page'),
            ),
      },
      home: const ParcelListScreen(),
    ),
  );
}

void main() {
  testWidgets('parcel list screen renders app shell', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        printerState: const PrinterState(),
      ),
    );
    await tester.pump();

    expect(find.text('TKT Parcel'), findsOneWidget);
  });

  testWidgets('home screen shows disconnected bluetooth icon', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        printerState: const PrinterState(),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.bluetooth_disabled), findsOneWidget);
  });

  testWidgets('home screen shows connected bluetooth icon', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        printerState: const PrinterState(
          connectedDevice: PrinterDevice(
            id: '00:11:22:33',
            name: 'Test Printer',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.bluetooth_connected), findsOneWidget);
  });

  testWidgets('tapping bluetooth icon opens printer connect page', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        printerState: const PrinterState(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('home-printer-action')));
    await tester.pumpAndSettle();

    expect(find.text('Printer Connect Page'), findsOneWidget);
  });
}
