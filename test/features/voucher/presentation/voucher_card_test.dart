import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkt_parcel/core/theme/app_theme.dart';
import 'package:tkt_parcel/data/models/enums/payment_status.dart';
import 'package:tkt_parcel/data/models/parcel.dart';
import 'package:tkt_parcel/features/voucher/presentation/widgets/voucher_card.dart';
import 'package:tkt_parcel/shared/models/app_setup_config.dart';

void main() {
  testWidgets(
    'renders voucher preview with tracking ID, QR section, and footer',
    (tester) async {
      final parcel = ParcelModel.create(
        trackingId: 'TGI-A1-250317-0001',
        fromTown: 'Taunggyi',
        toTown: 'Kalaw',
        cityCode: 'TGI',
        accountCode: 'A1',
        senderName: 'Ko Aung',
        senderPhone: '0912345678',
        receiverName: 'Ma Su',
        receiverPhone: '0998765432',
        parcelType: 'General',
        numberOfParcels: 2,
        totalCharges: 12000,
        paymentStatus: PaymentStatus.paid,
        remark: 'Fragile',
        now: DateTime(2025, 3, 17, 9, 30),
      );
      const setup = AppSetupConfig(
        cityCode: 'TGI',
        accountCode: 'A1',
        businessName: 'TKT Parcel',
        businessSubtitle: 'Parcel Voucher Service',
        businessPhone: '09-000-000000',
        footerMessage: 'Handle with care',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: VoucherCard(
                parcel: parcel,
                qrPayload: 'TRACK:TGI-A1-250317-0001',
                setup: setup,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('TKT Parcel'), findsOneWidget);
      expect(find.text('Tracking ID: TGI-A1-250317-0001'), findsOneWidget);
      expect(find.text('Remark: Fragile'), findsOneWidget);
      expect(find.text('Thank you for choosing TKT Parcel.'), findsOneWidget);
      expect(find.text('Handle with care'), findsOneWidget);
    },
  );
}
