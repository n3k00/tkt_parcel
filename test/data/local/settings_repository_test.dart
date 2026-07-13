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

  test('generates and reuses a stable device ID', () async {
    final firstDeviceId = await repository.getOrCreateDeviceId();
    final secondDeviceId = await repository.getOrCreateDeviceId();

    expect(firstDeviceId, isNotEmpty);
    expect(firstDeviceId, startsWith('device_'));
    expect(secondDeviceId, firstDeviceId);
  });

  test('maps source city codes to stable branch IDs', () {
    expect(repository.branchIdForCityCode('TGI'), 'source_tgi');
    expect(repository.branchIdForCityCode('lso'), 'source_lso');
    expect(repository.branchIdForCityCode('TCL'), 'source_tcl');
    expect(repository.branchIdForCityCode('LLM'), 'gate_llm');
    expect(repository.branchIdForCityCode('kgt'), 'gate_kgt');
    expect(repository.branchIdForCityCode('NYG'), 'source_nyg');
  });

  test('returns default address font size in app setup', () async {
    final setup = await repository.getAppSetup();

    expect(setup.businessAddressFontSize, 22);
    expect(setup.businessAddress, ReceiptStrings.defaultBusinessAddress);
  });
}
