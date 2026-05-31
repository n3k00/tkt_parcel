import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tkt_parcel/data/local/preferences/app_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores parcel pull cursor as UTC timestamp', () async {
    final preferences = await AppPreferences.create();
    final timestamp = DateTime.parse('2026-05-23T09:15:30+06:30');

    await preferences.setParcelPullLastSyncedAt(
      scope: 'tachileik-user',
      value: timestamp,
    );

    expect(
      preferences.getParcelPullLastSyncedAt(scope: 'tachileik-user'),
      timestamp.toUtc(),
    );
  });

  test('returns null when parcel pull cursor is missing or invalid', () async {
    final preferences = await AppPreferences.create();

    expect(preferences.getParcelPullLastSyncedAt(scope: 'lashio-user'), isNull);

    final sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setString(
      'parcel_pull_last_synced_at_lashio-user',
      'invalid',
    );

    expect(preferences.getParcelPullLastSyncedAt(scope: 'lashio-user'), isNull);
  });

  test(
    'keeps parcel pull cursors separate for each signed-in account',
    () async {
      final preferences = await AppPreferences.create();
      final tachileikTimestamp = DateTime.parse('2026-05-23T09:15:30Z');

      await preferences.setParcelPullLastSyncedAt(
        scope: 'tachileik-user',
        value: tachileikTimestamp,
      );

      expect(
        preferences.getParcelPullLastSyncedAt(scope: 'tachileik-user'),
        tachileikTimestamp,
      );
      expect(
        preferences.getParcelPullLastSyncedAt(scope: 'lashio-user'),
        isNull,
      );
    },
  );

  test('stores cached destination towns', () async {
    final preferences = await AppPreferences.create();

    await preferences.setCachedDestinationTowns([
      {'townName': 'လားရှိုး', 'type': 'destination', 'sortOrder': 28},
    ]);

    expect(preferences.getCachedDestinationTowns(), [
      {'townName': 'လားရှိုး', 'type': 'destination', 'sortOrder': 28},
    ]);
  });
}
