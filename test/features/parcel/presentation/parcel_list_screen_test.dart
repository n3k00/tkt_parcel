import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkt_parcel/core/theme/app_theme.dart';
import 'package:tkt_parcel/core/utils/date_utils.dart';
import 'package:tkt_parcel/data/models/enums/payment_status.dart';
import 'package:tkt_parcel/data/models/enums/parcel_status.dart';
import 'package:tkt_parcel/data/models/parcel.dart';
import 'package:tkt_parcel/features/auth/data/models/staff_profile.dart';
import 'package:tkt_parcel/features/auth/providers/auth_provider.dart';
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
            parcelHistoryProvider.overrideWith((ref) => Stream.value(parcels)),
            staffProfileProvider.overrideWith(
              (ref) async => const StaffProfile(
                userId: 'staff_tgi',
                branchId: 'source_tgi',
                role: 'staff',
                isActive: true,
                branchCityCode: 'TGI',
                branchTownName: 'Taunggyi',
              ),
            ),
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

  testWidgets('searches by tracking ID, receiver name, and receiver phone', (
    tester,
  ) async {
    final parcels = _sampleParcels();

    await _pumpParcelList(tester, parcels);

    final searchField = find.byKey(const Key('parcel-history-search-field'));

    await tester.enterText(searchField, '0002');
    await tester.pump();

    expect(find.text('Ma Nilar'), findsOneWidget);
    expect(find.text('Ma Su'), findsNothing);

    await tester.enterText(searchField, 'su');
    await tester.pump();

    expect(find.text('Ma Nilar'), findsNothing);
    expect(find.text('Ma Su'), findsOneWidget);

    await tester.enterText(searchField, '2222');
    await tester.pump();

    expect(find.text('Ma Nilar'), findsNothing);
    expect(find.text('Ma Su'), findsOneWidget);
  });

  testWidgets('keeps search field focused when search has no results', (
    tester,
  ) async {
    await _pumpParcelList(tester, _sampleParcels());

    final searchField = find.byKey(const Key('parcel-history-search-field'));
    await tester.tap(searchField);
    await tester.enterText(searchField, '3333');
    await tester.pump();

    final editableText = tester.state<EditableTextState>(
      find.byType(EditableText),
    );

    expect(find.text('No parcels found'), findsOneWidget);
    expect(editableText.widget.focusNode.hasFocus, isTrue);
  });

  testWidgets('hides cached parcels from other branch staff accounts', (
    tester,
  ) async {
    final parcels = [
      ParcelModel.create(
        trackingId: 'LSO-260523-0001',
        branchId: 'source_lso',
        fromTown: 'Lashio',
        toTown: 'Kalaw',
        cityCode: 'LSO',
        accountCode: 'A1',
        senderName: 'Ko LSO',
        senderPhone: '0911000000',
        receiverName: 'Ma LSO',
        receiverPhone: '0999111111',
        parcelType: 'Box',
        numberOfParcels: 1,
        totalCharges: 8000,
        paymentStatus: PaymentStatus.paid,
        now: DateTime(2026, 5, 23, 11, 0),
      ),
      ParcelModel.create(
        trackingId: 'TGI-260523-0001',
        branchId: 'source_tgi',
        fromTown: 'Taunggyi',
        toTown: 'Kalaw',
        cityCode: 'TGI',
        accountCode: 'A1',
        senderName: 'Ko TGI',
        senderPhone: '0912000000',
        receiverName: 'Ma TGI',
        receiverPhone: '0999222222',
        parcelType: 'Document',
        numberOfParcels: 1,
        totalCharges: 5000,
        paymentStatus: PaymentStatus.unpaid,
        now: DateTime(2026, 5, 23, 10, 0),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          parcelHistoryProvider.overrideWith((ref) => Stream.value(parcels)),
          staffProfileProvider.overrideWith(
            (ref) async => const StaffProfile(
              userId: 'staff_tgi',
              branchId: 'source_tgi',
              role: 'staff',
              isActive: true,
              branchCityCode: 'TGI',
              branchTownName: 'Taunggyi',
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ParcelListScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ma TGI'), findsOneWidget);
    expect(find.text('Ma LSO'), findsNothing);
    expect(find.text('0999222222'), findsOneWidget);
    expect(find.text('0999111111'), findsNothing);
  });

  testWidgets('hides split children but maps child tracking search to parent', (
    tester,
  ) async {
    final parent = ParcelModel.create(
      trackingId: 'TGI-260814-0001',
      branchId: 'source_tgi',
      fromTown: 'Taunggyi',
      toTown: 'Lashio',
      cityCode: 'TGI',
      accountCode: 'A1',
      senderName: 'Parent Sender',
      senderPhone: '0911000000',
      receiverName: 'Parent Receiver',
      receiverPhone: '0999000000',
      parcelType: 'Box',
      numberOfParcels: 4,
      totalCharges: 40000,
      paymentStatus: PaymentStatus.unpaid,
      now: DateTime(2026, 8, 14, 9, 0),
    ).copyWith(status: ParcelStatus.partiallySplit);
    final child = ParcelModel.create(
      trackingId: 'TGI-260814-0001-A',
      branchId: 'source_tgi',
      fromTown: 'Taunggyi',
      toTown: 'Lashio',
      cityCode: 'TGI',
      accountCode: 'A1',
      senderName: 'Child Sender',
      senderPhone: '0911000000',
      receiverName: 'Child Receiver',
      receiverPhone: '0999111111',
      parcelType: 'Bag',
      numberOfParcels: 2,
      totalCharges: 20000,
      paymentStatus: PaymentStatus.unpaid,
      now: DateTime(2026, 8, 14, 9, 5),
    ).copyWith(parentParcelId: 'server-parent-id', splitIndex: 'A');

    await _pumpParcelList(tester, [child, parent]);

    expect(find.text('Parent Receiver'), findsOneWidget);
    expect(find.text('Child Receiver'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('parcel-history-search-field')),
      'TGI-260814-0001-A',
    );
    await tester.pump();

    expect(find.text('Parent Receiver'), findsOneWidget);
    expect(find.text('Child Receiver'), findsNothing);
  });
}

List<ParcelModel> _sampleParcels() {
  return [
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
}

Future<void> _pumpParcelList(
  WidgetTester tester,
  List<ParcelModel> parcels,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        parcelHistoryProvider.overrideWith((ref) => Stream.value(parcels)),
        staffProfileProvider.overrideWith(
          (ref) async => const StaffProfile(
            userId: 'staff_tgi',
            branchId: 'source_tgi',
            role: 'staff',
            isActive: true,
            branchCityCode: 'TGI',
            branchTownName: 'Taunggyi',
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const ParcelListScreen(),
      ),
    ),
  );
  await tester.pump();
}
