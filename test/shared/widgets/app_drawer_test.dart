import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkt_parcel/features/auth/data/models/staff_profile.dart';
import 'package:tkt_parcel/features/auth/providers/auth_provider.dart';
import 'package:tkt_parcel/features/parcel/presentation/screens/home_screen.dart';
import 'package:tkt_parcel/shared/widgets/app_drawer.dart';

Widget _buildTestApp(StaffProfile profile) {
  return ProviderScope(
    overrides: [staffProfileProvider.overrideWith((ref) async => profile)],
    child: const MaterialApp(
      home: Scaffold(body: AppDrawer(currentRoute: HomeScreen.routeName)),
    ),
  );
}

void main() {
  testWidgets('main branch drawer hides gate operations', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        const StaffProfile(
          userId: 'staff_tgi',
          branchId: 'source_tgi',
          role: 'staff',
          isActive: true,
          branchCityCode: 'TGI',
          branchTownName: 'Taunggyi',
          branchType: 'main',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Main Ledger'), findsNothing);
    expect(find.text('Incoming Parcels'), findsNothing);
  });

  testWidgets('gate branch drawer shows gate operations', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        const StaffProfile(
          userId: 'staff_llm',
          branchId: 'gate_llm',
          role: 'staff',
          isActive: true,
          branchCityCode: 'LLM',
          branchTownName: 'Loilem',
          branchType: 'gate',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Main Ledger'), findsOneWidget);
    expect(find.text('Incoming Parcels'), findsOneWidget);
  });
}
