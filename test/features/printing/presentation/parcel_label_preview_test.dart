import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tkt_parcel/core/constants/label_strings.dart';
import 'package:tkt_parcel/core/theme/app_theme.dart';
import 'package:tkt_parcel/features/printing/presentation/widgets/parcel_label_print_widgets.dart';
import 'package:tkt_parcel/shared/models/label_settings_config.dart';

void main() {
  testWidgets('uses the provided business phone instead of label defaults', (
    tester,
  ) async {
    const configuredPhone = '09999999999, 08888888888';

    const trackingId = 'TGI-260805-0001';

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
            trackingId: trackingId,
          ),
        ),
      ),
    );

    expect(find.text(configuredPhone), findsOneWidget);
    expect(find.text(LabelStrings.businessPhone), findsNothing);
    expect(find.text('09123456789'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(trackingId), findsNothing);
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

  testWidgets('renders 75x90 shipping label with parcel details and note', (
    tester,
  ) async {
    final createdAt = DateTime(2026, 11, 7, 18, 10);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: ParcelLabelPreview(
              settings: const LabelSettingsConfig(
                labelSize: LabelSizePreset.mm75x90,
                titleFontSize: 60,
                subtitleFontSize: 24,
                bodyFontSize: 32,
                paddingTop: 12,
                paddingHorizontal: 18,
                rowGap: 10,
              ),
              businessPhone: '09666628053, 09679143312',
              name: 'မိုးကျော်နိုင်',
              phone: '09899794056',
              address: 'တောင်ကြီး',
              parcelType: 'ကျွတ်ခရမ်း',
              quantity: 1,
              note: 'အေးသာယာချိန်းရန်',
              createdAt: createdAt,
              trackingId: 'LSO-261107-0034',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Date: 07-11-2026'), findsOneWidget);
    expect(find.text('Parcel Type'), findsOneWidget);
    expect(find.text('ကျွတ်ခရမ်း'), findsOneWidget);
    expect(find.text('NOTE'), findsOneWidget);
    expect(find.text('အေးသာယာချိန်းရန်'), findsOneWidget);
    expect(find.text('LSO-261107-0034'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides empty note on 75x90 shipping label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 600,
            child: ParcelLabelPreview(
              settings: LabelSettingsConfig(
                labelSize: LabelSizePreset.mm75x90,
                titleFontSize: 60,
                subtitleFontSize: 24,
                bodyFontSize: 32,
                paddingTop: 12,
                paddingHorizontal: 18,
                rowGap: 10,
              ),
              businessPhone: '09666628053',
              name: 'Receiver',
              phone: '09123456789',
              address: 'Taunggyi',
              parcelType: 'Box',
              quantity: 1,
              trackingId: 'TGI-261108-0001',
            ),
          ),
        ),
      ),
    );

    expect(find.text('NOTE'), findsNothing);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('limits long 75x90 parcel type without changing other data', (
    tester,
  ) async {
    const longParcelType =
        'အဝတ်အထည်နှင့် လူသုံးကုန်ပစ္စည်းအမျိုးအစားအစုံအလင် ထည့်ထားသောအထုပ်ကြီး';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 600,
            child: ParcelLabelPreview(
              settings: LabelSettingsConfig(
                labelSize: LabelSizePreset.mm75x90,
                titleFontSize: 60,
                subtitleFontSize: 24,
                bodyFontSize: 32,
                paddingTop: 12,
                paddingHorizontal: 18,
                rowGap: 10,
              ),
              businessPhone: '09666628053',
              name: 'Receiver',
              phone: '09123456789',
              address: 'Taunggyi',
              parcelType: longParcelType,
              quantity: 1,
              trackingId: 'TGI-261108-0001',
            ),
          ),
        ),
      ),
    );

    expect(find.text(longParcelType), findsNothing);
    expect(find.textContaining('…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('applies the selected 75x90 font sizes to rendered text', (
    tester,
  ) async {
    Future<void> pumpWith({
      required double title,
      required double subtitle,
      required double body,
      required double fieldLabel,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: ParcelLabelPreview(
                settings: LabelSettingsConfig(
                  labelSize: LabelSizePreset.mm75x90,
                  titleFontSize: title,
                  subtitleFontSize: subtitle,
                  bodyFontSize: body,
                  fieldLabelFontSize: fieldLabel,
                  paddingTop: 12,
                  paddingHorizontal: 18,
                  rowGap: 8,
                ),
                businessPhone: '09666628053',
                name: 'မိုးကျော်နိုင်',
                phone: '09123456789',
                address: 'Taunggyi',
                parcelType: 'Box',
                quantity: 1,
                createdAt: DateTime(2026, 11, 8),
                trackingId: 'TGI-261108-0001',
              ),
            ),
          ),
        ),
      );
    }

    await pumpWith(title: 36, subtitle: 14, body: 20, fieldLabel: 16);
    expect(
      tester
          .widget<Text>(find.text(LabelStrings.businessTitle))
          .style
          ?.fontSize,
      36,
    );
    expect(tester.widget<Text>(find.text('09666628053')).style?.fontSize, 14);
    expect(
      tester.widget<Text>(find.text('မိုးကျော်နိုင်')).style?.fontSize,
      20,
    );
    expect(tester.widget<Text>(find.text('Receiver')).style?.fontSize, 16);

    await pumpWith(title: 72, subtitle: 28, body: 38, fieldLabel: 30);
    expect(
      tester
          .widget<Text>(find.text(LabelStrings.businessTitle))
          .style
          ?.fontSize,
      72,
    );
    expect(tester.widget<Text>(find.text('09666628053')).style?.fontSize, 28);
    expect(
      tester.widget<Text>(find.text('မိုးကျော်နိုင်')).style?.fontSize,
      38,
    );
    expect(tester.widget<Text>(find.text('Receiver')).style?.fontSize, 30);
    expect(tester.takeException(), isNull);
  });

  testWidgets('applies field label font independently from body values', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: ParcelLabelPreview(
              settings: const LabelSettingsConfig(
                labelSize: LabelSizePreset.mm75x90,
                titleFontSize: 48,
                subtitleFontSize: 18,
                bodyFontSize: 28,
                fieldLabelFontSize: 17,
                paddingTop: 12,
                paddingHorizontal: 18,
                rowGap: 8,
              ),
              businessPhone: '09666628053',
              name: 'မိုးကျော်နိုင်',
              phone: '09123456789',
              address: 'Taunggyi',
              parcelType: 'Box',
              quantity: 1,
              createdAt: DateTime(2026, 11, 8),
              trackingId: 'TGI-261108-0001',
            ),
          ),
        ),
      ),
    );

    expect(tester.widget<Text>(find.text('Receiver')).style?.fontSize, 17);
    expect(
      tester.widget<Text>(find.text('မိုးကျော်နိုင်')).style?.fontSize,
      28,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('applies the selected 75x90 row gap to rendered spacing', (
    tester,
  ) async {
    Future<double> receiverToPhoneDistance(double rowGap) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: ParcelLabelPreview(
                settings: LabelSettingsConfig(
                  labelSize: LabelSizePreset.mm75x90,
                  titleFontSize: 48,
                  subtitleFontSize: 18,
                  bodyFontSize: 24,
                  fieldLabelFontSize: 18,
                  paddingTop: 12,
                  paddingHorizontal: 18,
                  rowGap: rowGap,
                ),
                businessPhone: '09666628053',
                name: 'Receiver Name',
                phone: '09123456789',
                address: 'Taunggyi',
                parcelType: 'Box',
                quantity: 1,
                createdAt: DateTime(2026, 11, 8),
                trackingId: 'TGI-261108-0001',
              ),
            ),
          ),
        ),
      );

      final receiverTop = tester.getTopLeft(find.text('Receiver')).dy;
      final phoneTop = tester.getTopLeft(find.text('Phone')).dy;
      return phoneTop - receiverTop;
    }

    final zeroGapDistance = await receiverToPhoneDistance(0);
    final maximumGapDistance = await receiverToPhoneDistance(12);

    expect(maximumGapDistance, greaterThan(zeroGapDistance));
    expect(tester.takeException(), isNull);
  });
}
