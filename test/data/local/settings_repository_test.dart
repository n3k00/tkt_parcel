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

  test('saves 75x90 portrait label size', () async {
    final initial = await repository.getLabelSettings();

    await repository.saveLabelSettings(
      initial.copyWith(labelSize: LabelSizePreset.mm75x90),
    );

    final saved = await repository.getLabelSettings();
    expect(saved.labelSize, LabelSizePreset.mm75x90);
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

  test('saves field label font size separately from body font size', () async {
    final initial = await repository.getLabelSettings();

    await repository.saveLabelSettings(
      initial.copyWith(bodyFontSize: 40, fieldLabelFontSize: 28),
    );

    final saved = await repository.getLabelSettings();
    expect(saved.bodyFontSize, 40);
    expect(saved.fieldLabelFontSize, 28);
  });

  test('keeps independent settings for each label size', () async {
    final compact = await repository.getLabelSettings(
      forSize: LabelSizePreset.mm75x50,
    );
    final portrait = await repository.getLabelSettings(
      forSize: LabelSizePreset.mm75x90,
    );

    await repository.saveLabelSettings(
      compact.copyWith(
        titleFontSize: 70,
        bodyFontSize: 38,
        fieldLabelFontSize: 30,
        paddingTop: 10,
        rowGap: 6,
      ),
    );
    await repository.saveLabelSettings(
      portrait.copyWith(
        titleFontSize: 48,
        bodyFontSize: 24,
        fieldLabelFontSize: 18,
        paddingTop: 4,
        rowGap: 12,
      ),
    );

    final savedCompact = await repository.getLabelSettings(
      forSize: LabelSizePreset.mm75x50,
    );
    final savedPortrait = await repository.getLabelSettings(
      forSize: LabelSizePreset.mm75x90,
    );

    expect(savedCompact.titleFontSize, 70);
    expect(savedCompact.bodyFontSize, 38);
    expect(savedCompact.fieldLabelFontSize, 30);
    expect(savedCompact.paddingTop, 10);
    expect(savedCompact.rowGap, 6);
    expect(savedPortrait.titleFontSize, 48);
    expect(savedPortrait.bodyFontSize, 24);
    expect(savedPortrait.fieldLabelFontSize, 18);
    expect(savedPortrait.paddingTop, 4);
    expect(savedPortrait.rowGap, 12);
  });

  test(
    'uses legacy shared label values when a size profile is missing',
    () async {
      SharedPreferences.setMockInitialValues({
        'label_title_font_size': 66.0,
        'label_body_font_size': 36.0,
        'label_padding_top': 14.0,
      });
      final preferences = await AppPreferences.create();
      final legacyRepository = SettingsRepository(preferences);

      final settings = await legacyRepository.getLabelSettings(
        forSize: LabelSizePreset.mm80x60,
      );

      expect(settings.titleFontSize, 66);
      expect(settings.bodyFontSize, 36);
      expect(settings.paddingTop, 14);
    },
  );
}
