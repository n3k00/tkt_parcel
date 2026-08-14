import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tkt_parcel/core/constants/receipt_strings.dart';
import 'package:tkt_parcel/data/local/preferences/app_preferences.dart';
import 'package:tkt_parcel/data/repositories/settings_repository.dart';
import 'package:tkt_parcel/shared/models/label_settings_config.dart';

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

  test('returns 75x50 label size by default', () async {
    final settings = await repository.getLabelSettings();

    expect(settings.labelSize, LabelSizePreset.mm75x50);
  });

  test('saves selected label size', () async {
    final initial = await repository.getLabelSettings();

    await repository.saveLabelSettings(
      initial.copyWith(labelSize: LabelSizePreset.mm80x60),
    );

    final saved = await repository.getLabelSettings();
    expect(saved.labelSize, LabelSizePreset.mm80x60);
  });

  test('saves zero label padding values', () async {
    final initial = await repository.getLabelSettings();

    await repository.saveLabelSettings(
      initial.copyWith(paddingTop: 0, paddingHorizontal: 0, rowGap: 0),
    );

    final saved = await repository.getLabelSettings();
    expect(saved.paddingTop, 0);
    expect(saved.paddingHorizontal, 0);
    expect(saved.rowGap, 0);
  });
}
