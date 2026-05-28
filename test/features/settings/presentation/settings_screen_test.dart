import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkt_parcel/core/constants/app_strings.dart';
import 'package:tkt_parcel/core/services/app_info_service.dart';
import 'package:tkt_parcel/core/theme/app_theme.dart';
import 'package:tkt_parcel/features/auth/presentation/screens/account_screen.dart';
import 'package:tkt_parcel/features/printer/presentation/screens/printer_settings_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/providers/settings_provider.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/from_town_settings_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/receipt_settings_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/settings_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/backup_restore_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/label_settings_screen.dart';

void main() {
  const appInfo = AppVersionInfo(
    appName: 'TKT Parcel',
    packageName: 'com.theinkhathu.parcel',
    version: '1.0.0',
    buildNumber: '1',
  );

  testWidgets('shows current settings entries and navigates to account', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsDataProvider.overrideWith(
            (ref) async => const SettingsViewData(appInfo: appInfo),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          routes: {
            AccountScreen.routeName: (_) =>
                const Scaffold(body: Text('Account Page')),
            FromTownSettingsScreen.routeName: (_) =>
                const Scaffold(body: Text('From Town Page')),
            ReceiptSettingsScreen.routeName: (_) =>
                const Scaffold(body: Text('Receipt Settings Page')),
            LabelSettingsScreen.routeName: (_) =>
                const Scaffold(body: Text('Label Settings Page')),
            PrinterSettingsScreen.routeName: (_) =>
                const Scaffold(body: Text('Printer Settings Page')),
            BackupRestoreScreen.routeName: (_) =>
                const Scaffold(body: Text('Backup and Restore Page')),
          },
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
    expect(find.text(AppStrings.fromTownTitle), findsOneWidget);
    expect(find.text('Voucher Header'), findsNothing);
    expect(find.text(AppStrings.receiptSettingsTitle), findsOneWidget);
    expect(find.text(AppStrings.labelSettingsTitle), findsOneWidget);
    expect(find.text('To Town'), findsNothing);
    expect(find.text(AppStrings.printerSettingsTitle), findsOneWidget);
    expect(find.text('Account Info'), findsNothing);

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    expect(find.text('Account Page'), findsOneWidget);
  });

  testWidgets('shows lower settings entries after scrolling', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsDataProvider.overrideWith(
            (ref) async => const SettingsViewData(appInfo: appInfo),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          routes: {
            BackupRestoreScreen.routeName: (_) =>
                const Scaffold(body: Text('Backup and Restore Page')),
          },
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text(AppStrings.backupRestoreTitle),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text(AppStrings.backupRestoreTitle), findsOneWidget);
  });
}
