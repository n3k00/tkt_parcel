import 'package:flutter_test/flutter_test.dart';
import 'package:tkt_parcel/data/models/enums/parcel_status.dart';

void main() {
  test(
    'parses cancelled status and falls back to received for unknown values',
    () {
      expect(
        ParcelStatus.fromValue('partially_split'),
        ParcelStatus.partiallySplit,
      );
      expect(ParcelStatus.fromValue('split'), ParcelStatus.split);
      expect(ParcelStatus.fromValue('cancelled'), ParcelStatus.cancelled);
      expect(ParcelStatus.fromValue('legacy_unknown'), ParcelStatus.received);
    },
  );
}
