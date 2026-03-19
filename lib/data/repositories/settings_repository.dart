import '../../shared/models/app_setup_config.dart';
import '../local/preferences/app_preferences.dart';

class SettingsRepository {
  SettingsRepository(this._preferences);

  static const _defaultCityCode = 'TGI';
  static const _defaultAccountCode = 'A1';
  static const _defaultBusinessName = 'TKT Parcel';
  static const _defaultBusinessSubtitle = 'Parcel Voucher Service';
  static const _defaultBusinessPhone = '09-000-000000';
  static const _defaultFooterMessage = '';
  static const _defaultTownList = [
    'Taunggyi',
    'Aungban',
    'Kalaw',
    'Hopong',
    'Heho',
    'Nyaungshwe',
  ];

  final AppPreferences _preferences;

  Future<AppSetupConfig> getAppSetup() async {
    final cityCode = _preferences.getCityCode() ?? _defaultCityCode;
    final accountCode = _preferences.getAccountCode() ?? _defaultAccountCode;

    return AppSetupConfig(
      cityCode: cityCode.toUpperCase(),
      accountCode: accountCode.toUpperCase(),
      businessName: _preferences.getBusinessName() ?? _defaultBusinessName,
      businessSubtitle:
          _preferences.getBusinessSubtitle() ?? _defaultBusinessSubtitle,
      businessPhone: _preferences.getBusinessPhone() ?? _defaultBusinessPhone,
      footerMessage: _preferences.getFooterMessage() ?? _defaultFooterMessage,
    );
  }

  Future<void> saveAppSetup(AppSetupConfig config) async {
    await _preferences.setCityCode(config.cityCode.toUpperCase());
    await _preferences.setAccountCode(config.accountCode.toUpperCase());
    await _preferences.setBusinessName(config.businessName.trim());
    await _preferences.setBusinessSubtitle(config.businessSubtitle.trim());
    await _preferences.setBusinessPhone(config.businessPhone.trim());
    await _preferences.setFooterMessage((config.footerMessage ?? '').trim());
  }

  Future<List<String>> getTownList() async {
    final towns = _preferences.getTownList();
    if (towns == null || towns.isEmpty) {
      await _preferences.setTownList(_defaultTownList);
      return _defaultTownList;
    }

    return towns;
  }

  Future<void> saveTownList(List<String> towns) async {
    final normalized = towns
        .map((town) => town.trim())
        .where((town) => town.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    await _preferences.setTownList(normalized);
  }
}
