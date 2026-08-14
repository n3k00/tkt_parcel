import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkt_parcel/core/constants/label_strings.dart';
import 'package:tkt_parcel/core/theme/app_theme.dart';
import 'package:tkt_parcel/features/printing/presentation/widgets/parcel_label_print_widgets.dart';
import 'package:tkt_parcel/shared/models/label_settings_config.dart';

void main() {
  testWidgets('uses the provided business phone instead of label defaults', (
    tester,
  ) async {
    const configuredPhone = '09999999999, 08888888888';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: ParcelLabelPreview(
            settings: LabelSettingsConfig(
              labelSize: LabelSizePreset.mm75x50,
              titleFontSize: 36,
              subtitleFontSize: 18,
              bodyFontSize: 20,
              paddingTop: 12,
              paddingHorizontal: 18,
              rowGap: 8,
            ),
            businessPhone: configuredPhone,
            name: 'Receiver',
            phone: '09123456789',
            address: 'Tachileik',
            quantity: 3,
            trackingId: 'TGI-260805-0001',
          ),
        ),
      ),
    );

    expect(find.text(configuredPhone), findsOneWidget);
    expect(find.text(LabelStrings.businessPhone), findsNothing);
    expect(find.text('09123456789'), findsOneWidget);
  });

  testWidgets('renders 80x60 QR layout with compact details', (tester) async {
    const trackingId = 'TGI-260805-0001';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 640,
            child: ParcelLabelPreview(
              settings: LabelSettingsConfig(
                labelSize: LabelSizePreset.mm80x60,
                titleFontSize: 48,
                subtitleFontSize: 20,
                bodyFontSize: 20,
                paddingTop: 12,
                paddingHorizontal: 18,
                rowGap: 8,
              ),
              businessPhone: '09250787547,09253003004',
              name: 'ကိုကျော်',
              phone: '09794249873,09999999999',
              address: 'တာချီလိတ်',
              quantity: 3,
              trackingId: trackingId,
            ),
          ),
        ),
      ),
    );

    expect(find.text(trackingId), findsOneWidget);
    expect(find.text('Qty'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps 80x60 layout printable with maximum saved settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 640,
            child: ParcelLabelPreview(
              settings: LabelSettingsConfig(
                labelSize: LabelSizePreset.mm80x60,
                titleFontSize: 110,
                subtitleFontSize: 52,
                bodyFontSize: 64,
                paddingTop: 80,
                paddingHorizontal: 80,
                rowGap: 40,
              ),
              businessPhone: '09250787547,09253003004',
              name: 'ကိုကျော်',
              phone: '09794249873,09999999999',
              address: 'တာချီလိတ်',
              quantity: 3,
              trackingId: 'TGI-260805-0001',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Qty'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders 80x60 QR layout with safe inset for zero padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 640,
            child: ParcelLabelPreview(
              settings: LabelSettingsConfig(
                labelSize: LabelSizePreset.mm80x60,
                titleFontSize: 52,
                subtitleFontSize: 22,
                bodyFontSize: 30,
                paddingTop: 0,
                paddingHorizontal: 0,
                rowGap: 8,
              ),
              businessPhone: '09250787547,09253003004',
              name: 'á€€á€­á€¯á€€á€»á€±á€¬á€º',
              phone: '09794249873',
              address: 'á€á€¬á€á€»á€®á€œá€­á€á€º',
              quantity: 3,
              trackingId: 'TGI-260805-0001',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Address'), findsOneWidget);
    expect(find.text('Qty'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
