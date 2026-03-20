import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tkt_parcel/core/theme/app_theme.dart';
import 'package:tkt_parcel/data/local/preferences/app_preferences.dart';
import 'package:tkt_parcel/data/repositories/settings_repository.dart';
import 'package:tkt_parcel/features/printer/presentation/screens/printer_settings_screen.dart';
import 'package:tkt_parcel/providers/parcel_repository_provider.dart';

void main() {
  testWidgets('selecting printer preset saves the selected value', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await AppPreferences.create();
    final repository = SettingsRepository(preferences);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PrinterSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(await repository.getPrinterPreset(), 'dark');
    expect(find.text('Dark preset selected.'), findsOneWidget);
  });
}
