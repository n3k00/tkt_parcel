import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkt_parcel/core/constants/app_strings.dart';
import 'package:tkt_parcel/core/constants/receipt_strings.dart';
import 'package:tkt_parcel/core/services/app_info_service.dart';
import 'package:tkt_parcel/core/theme/app_theme.dart';
import 'package:tkt_parcel/features/printer/presentation/screens/printer_settings_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/providers/settings_provider.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/from_town_settings_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/profile_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/receipt_settings_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/settings_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/staff_account_info_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/backup_restore_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/label_settings_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/to_town_settings_screen.dart';
import 'package:tkt_parcel/shared/models/app_setup_config.dart';

void main() {
  const setup = AppSetupConfig(
    cityCode: 'TGI',
    accountCode: 'A1',
    businessName: ReceiptStrings.defaultBusinessName,
    businessSubtitle: ReceiptStrings.defaultBusinessSubtitle,
    businessAddress: ReceiptStrings.defaultBusinessAddress,
    businessPhone: ReceiptStrings.defaultBusinessPhone,
    businessNameFontSize: 60,
    businessSubtitleFontSize: 26,
    businessAddressFontSize: 22,
    businessPhoneFontSize: 20,
    receiptLabelFontSize: 28,
    receiptValueFontSize: 30,
    receiptPaddingTop: 20,
    receiptPaddingLeft: 24,
    receiptPaddingRight: 24,
    receiptPaddingBottom: 40,
    footerMessage: '',
  );

  const appInfo = AppVersionInfo(
    appName: 'TKT Parcel',
    packageName: 'com.theinkhathu.parcel',
    version: '1.0.0',
    buildNumber: '1',
  );

  testWidgets('shows current settings entries and navigates to profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsDataProvider.overrideWith(
            (ref) async =>
                const SettingsViewData(setup: setup, appInfo: appInfo),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          routes: {
            ProfileScreen.routeName: (_) =>
                const Scaffold(body: Text('Profile Page')),
            FromTownSettingsScreen.routeName: (_) =>
                const Scaffold(body: Text('From Town Page')),
            StaffAccountInfoScreen.routeName: (_) =>
                const Scaffold(body: Text('Voucher Header Page')),
            ReceiptSettingsScreen.routeName: (_) =>
                const Scaffold(body: Text('Receipt Settings Page')),
            LabelSettingsScreen.routeName: (_) =>
                const Scaffold(body: Text('Label Settings Page')),
            ToTownSettingsScreen.routeName: (_) =>
                const Scaffold(body: Text('To Town Page')),
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

    expect(find.text(AppStrings.profileTitle), findsOneWidget);
    expect(find.text(AppStrings.fromTownTitle), findsOneWidget);
    expect(find.text(AppStrings.voucherHeaderTitle), findsOneWidget);
    expect(find.text(AppStrings.receiptSettingsTitle), findsOneWidget);
    expect(find.text(AppStrings.labelSettingsTitle), findsOneWidget);
    expect(find.text(AppStrings.toTownTitle), findsOneWidget);
    expect(find.text(AppStrings.printerSettingsTitle), findsOneWidget);
    expect(find.text('Account Info'), findsNothing);

    await tester.tap(find.text(AppStrings.profileTitle));
    await tester.pumpAndSettle();

    expect(find.text('Profile Page'), findsOneWidget);
  });

  testWidgets('shows lower settings entries after scrolling', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsDataProvider.overrideWith(
            (ref) async =>
                const SettingsViewData(setup: setup, appInfo: appInfo),
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
