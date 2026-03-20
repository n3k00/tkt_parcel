import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tkt_parcel/core/constants/receipt_strings.dart';
import 'package:tkt_parcel/data/local/preferences/app_preferences.dart';
import 'package:tkt_parcel/data/repositories/settings_repository.dart';

void main() {
  late SettingsRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await AppPreferences.create();
    repository = SettingsRepository(preferences);
  });

  test('returns balanced printer preset by default', () async {
    final preset = await repository.getPrinterPreset();

    expect(preset, 'balanced');
  });

  test('saves and loads default source town name', () async {
    await repository.saveDefaultSourceTownName('လားရှိုး');

    final value = await repository.getDefaultSourceTownName();

    expect(value, 'လားရှိုး');
  });

  test('returns default address font size in app setup', () async {
    final setup = await repository.getAppSetup();

    expect(setup.businessAddressFontSize, 22);
    expect(setup.businessAddress, ReceiptStrings.defaultBusinessAddress);
  });
}
