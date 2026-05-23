import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkt_parcel/core/theme/app_theme.dart';
import 'package:tkt_parcel/core/utils/date_utils.dart';
import 'package:tkt_parcel/data/models/enums/parcel_status.dart';
import 'package:tkt_parcel/data/models/enums/payment_status.dart';
import 'package:tkt_parcel/data/models/parcel.dart';
import 'package:tkt_parcel/features/voucher/presentation/widgets/dispatch_info_section.dart';

void main() {
  testWidgets('hides dispatch info when no dispatch data exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(child: DispatchInfoSection(parcel: _buildParcel())),
    );

    expect(find.text('Dispatch Info'), findsNothing);
    expect(find.text('Dispatch Status'), findsNothing);
  });

  testWidgets('shows dispatch info when dispatch data exists', (tester) async {
    final dispatchedDate = DateTime(2025, 3, 17, 12, 30);
    final parcel = _buildParcel().copyWith(
      status: ParcelStatus.dispatched,
      driverName: 'Ko Driver',
      driverPhone: '09111222333',
      dispatchedDate: dispatchedDate,
      claimNote: 'Receiver will collect tomorrow.',
    );

    await tester.pumpWidget(
      _TestApp(child: DispatchInfoSection(parcel: parcel)),
    );

    expect(find.text('Dispatch Info'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
    expect(find.text('Ko Driver'), findsOneWidget);
    expect(find.text('Driver Phone'), findsOneWidget);
    expect(find.text('09111222333'), findsOneWidget);
    expect(find.text('Dispatched Date'), findsOneWidget);
    expect(
      find.text(AppDateUtils.formatDateTime12Hour(dispatchedDate)),
      findsOneWidget,
    );
    expect(find.text('Dispatch Status'), findsOneWidget);
    expect(find.text('dispatched'), findsOneWidget);
    expect(find.text('Claim Note'), findsOneWidget);
    expect(find.text('Receiver will collect tomorrow.'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );
  }
}

ParcelModel _buildParcel() {
  return ParcelModel.create(
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
    numberOfParcels: 1,
    totalCharges: 7000,
    paymentStatus: PaymentStatus.paid,
    now: DateTime(2025, 3, 17, 9),
  );
}
