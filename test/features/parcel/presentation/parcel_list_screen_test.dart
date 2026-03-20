import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkt_parcel/core/theme/app_theme.dart';
import 'package:tkt_parcel/core/utils/date_utils.dart';
import 'package:tkt_parcel/data/models/enums/payment_status.dart';
import 'package:tkt_parcel/data/models/parcel.dart';
import 'package:tkt_parcel/features/parcel/presentation/providers/parcel_list_provider.dart';
import 'package:tkt_parcel/features/parcel/presentation/screens/parcel_list_screen.dart';

void main() {
  testWidgets(
    'loads parcel history from local state and shows latest parcel first',
    (tester) async {
      final parcels = [
        ParcelModel.create(
          trackingId: 'TGI-A1-250317-0002',
          fromTown: 'Taunggyi',
          toTown: 'Kalaw',
          cityCode: 'TGI',
          accountCode: 'A1',
          senderName: 'Ko Zaw',
          senderPhone: '0911000000',
          receiverName: 'Ma Nilar',
          receiverPhone: '0999111111',
          parcelType: 'Box',
          numberOfParcels: 1,
          totalCharges: 8000,
          paymentStatus: PaymentStatus.paid,
          now: DateTime(2025, 3, 17, 11, 0),
        ),
        ParcelModel.create(
          trackingId: 'TGI-A1-250317-0001',
          fromTown: 'Taunggyi',
          toTown: 'Kalaw',
          cityCode: 'TGI',
          accountCode: 'A1',
          senderName: 'Ko Aung',
          senderPhone: '0912000000',
          receiverName: 'Ma Su',
          receiverPhone: '0999222222',
          parcelType: 'Document',
          numberOfParcels: 1,
          totalCharges: 5000,
          paymentStatus: PaymentStatus.unpaid,
          now: DateTime(2025, 3, 17, 10, 0),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            parcelListProvider.overrideWith((ref) => Stream.value(parcels)),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ParcelListScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Ma Nilar'), findsOneWidget);
      expect(find.text('Ma Su'), findsOneWidget);
      expect(find.text('Kalaw'), findsNWidgets(2));
      expect(find.text('0999111111'), findsOneWidget);
      expect(find.text('0999222222'), findsOneWidget);
      expect(
        find.text(AppDateUtils.formatDateTime12Hour(parcels.first.createdAt)),
        findsOneWidget,
      );
    },
  );
}
