import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkt_parcel/core/services/app_info_service.dart';
import 'package:tkt_parcel/core/theme/app_theme.dart';
import 'package:tkt_parcel/features/printer/presentation/screens/printer_settings_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/providers/settings_provider.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/from_town_settings_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/profile_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/receipt_settings_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/settings_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/staff_account_info_screen.dart';
import 'package:tkt_parcel/features/settings/presentation/screens/to_town_settings_screen.dart';
import 'package:tkt_parcel/shared/models/app_setup_config.dart';

void main() {
  const setup = AppSetupConfig(
    cityCode: 'TGI',
    accountCode: 'A1',
    businessName: 'သိင်္ခသူ',
    businessSubtitle: 'ခရီးသည် နှင့် ကုန်စည် ပို့ဆောင်ရေး',
    businessAddress: 'ပါဆပ်ကားလေးကွင်း၊တာချီလိတ်မြို့။',
    businessPhone: '09250787547,09253003004',
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
            (ref) async => const SettingsViewData(setup: setup, appInfo: appInfo),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          routes: {
            ProfileScreen.routeName: (_) => const Scaffold(body: Text('Profile Page')),
            FromTownSettingsScreen.routeName: (_) =>
                const Scaffold(body: Text('From Town Page')),
            StaffAccountInfoScreen.routeName: (_) =>
                const Scaffold(body: Text('Voucher Header Page')),
            ReceiptSettingsScreen.routeName: (_) =>
                const Scaffold(body: Text('Receipt Settings Page')),
            ToTownSettingsScreen.routeName: (_) =>
                const Scaffold(body: Text('To Town Page')),
            PrinterSettingsScreen.routeName: (_) =>
                const Scaffold(body: Text('Printer Settings Page')),
          },
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('From Town'), findsOneWidget);
    expect(find.text('Voucher Header'), findsOneWidget);
    expect(find.text('Receipt Settings'), findsOneWidget);
    expect(find.text('To Town'), findsOneWidget);
    expect(find.text('Printer Settings'), findsOneWidget);
    expect(find.text('Account Info'), findsNothing);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Profile Page'), findsOneWidget);
  });
}
