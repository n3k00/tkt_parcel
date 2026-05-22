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
          ),
        ),
      ),
    );

    expect(find.text(configuredPhone), findsOneWidget);
    expect(find.text(LabelStrings.businessPhone), findsNothing);
    expect(find.text('09123456789'), findsOneWidget);
  });
}
