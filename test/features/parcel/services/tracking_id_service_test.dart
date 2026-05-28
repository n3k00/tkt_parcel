import 'package:flutter_test/flutter_test.dart';
import 'package:tkt_parcel/core/services/tracking_id_service.dart';

void main() {
  const service = TrackingIdService();

  test('generates tracking ID from city code and date', () {
    final trackingId = service.generate(
      cityCode: 'tgi',
      now: DateTime(2025, 3, 17),
      runningNumber: 1,
    );

    expect(trackingId, 'TGI-250317-0001');
  });

  test('increments running number within the same day', () {
    final first = service.generate(
      cityCode: 'TGI',
      now: DateTime(2025, 3, 17),
      runningNumber: 1,
    );
    final second = service.generate(
      cityCode: 'TGI',
      now: DateTime(2025, 3, 17),
      runningNumber: 2,
    );

    expect(first, 'TGI-250317-0001');
    expect(second, 'TGI-250317-0002');
  });

  test('resets running number when the date changes', () {
    final previousDay = service.generate(
      cityCode: 'TGI',
      now: DateTime(2025, 3, 17),
      runningNumber: 18,
    );
    final nextDay = service.generate(
      cityCode: 'TGI',
      now: DateTime(2025, 3, 18),
      runningNumber: 1,
    );

    expect(previousDay, 'TGI-250317-0018');
    expect(nextDay, 'TGI-250318-0001');
  });
}
