import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences(this._preferences);

  static const _cityCodeKey = 'setup_city_code';
  static const _accountCodeKey = 'setup_account_code';
  static const _townListKey = 'setup_town_list';
  static const _businessNameKey = 'business_name';
  static const _businessSubtitleKey = 'business_subtitle';
  static const _businessPhoneKey = 'business_phone';
  static const _footerMessageKey = 'voucher_footer_message';

  final SharedPreferences _preferences;

  static Future<AppPreferences> create() async {
    final preferences = await SharedPreferences.getInstance();
    return AppPreferences(preferences);
  }

  String? getCityCode() => _preferences.getString(_cityCodeKey);

  String? getAccountCode() => _preferences.getString(_accountCodeKey);

  Future<bool> setCityCode(String value) {
    return _preferences.setString(_cityCodeKey, value);
  }

  Future<bool> setAccountCode(String value) {
    return _preferences.setString(_accountCodeKey, value);
  }

  List<String>? getTownList() => _preferences.getStringList(_townListKey);

  Future<bool> setTownList(List<String> values) {
    return _preferences.setStringList(_townListKey, values);
  }

  String? getBusinessName() => _preferences.getString(_businessNameKey);

  String? getBusinessSubtitle() => _preferences.getString(_businessSubtitleKey);

  String? getBusinessPhone() => _preferences.getString(_businessPhoneKey);

  String? getFooterMessage() => _preferences.getString(_footerMessageKey);

  Future<bool> setBusinessName(String value) {
    return _preferences.setString(_businessNameKey, value);
  }

  Future<bool> setBusinessSubtitle(String value) {
    return _preferences.setString(_businessSubtitleKey, value);
  }

  Future<bool> setBusinessPhone(String value) {
    return _preferences.setString(_businessPhoneKey, value);
  }

  Future<bool> setFooterMessage(String value) {
    return _preferences.setString(_footerMessageKey, value);
  }
}
