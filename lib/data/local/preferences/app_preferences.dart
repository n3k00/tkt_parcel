import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences(this._preferences);

  static const _deviceIdKey = 'device_id';
  static const _cityCodeKey = 'setup_city_code';
  static const _accountCodeKey = 'setup_account_code';
  static const _businessNameKey = 'business_name';
  static const _businessSubtitleKey = 'business_subtitle';
  static const _businessAddressKey = 'business_address';
  static const _businessPhoneKey = 'business_phone';
  static const _businessNameFontSizeKey = 'business_name_font_size';
  static const _businessSubtitleFontSizeKey = 'business_subtitle_font_size';
  static const _businessAddressFontSizeKey = 'business_address_font_size';
  static const _businessPhoneFontSizeKey = 'business_phone_font_size';
  static const _receiptLabelFontSizeKey = 'receipt_label_font_size';
  static const _receiptValueFontSizeKey = 'receipt_value_font_size';
  static const _receiptPaddingTopKey = 'receipt_padding_top';
  static const _receiptPaddingLeftKey = 'receipt_padding_left';
  static const _receiptPaddingRightKey = 'receipt_padding_right';
  static const _receiptPaddingBottomKey = 'receipt_padding_bottom';
  static const _footerMessageKey = 'voucher_footer_message';
  static const _printerPresetKey = 'printer_preset';
  static const _labelTitleFontSizeKey = 'label_title_font_size';
  static const _labelSubtitleFontSizeKey = 'label_subtitle_font_size';
  static const _labelBodyFontSizeKey = 'label_body_font_size';
  static const _labelPaddingTopKey = 'label_padding_top';
  static const _labelPaddingHorizontalKey = 'label_padding_horizontal';
  static const _labelRowGapKey = 'label_row_gap';
  static const _lastLabelPrinterIdKey = 'last_label_printer_id';
  static const _lastLabelPrinterNameKey = 'last_label_printer_name';
  static const _parcelPullLastSyncedAtKey = 'parcel_pull_last_synced_at';
  static const _cachedStaffProfileKey = 'cached_staff_profile';
  static const _cachedSourceBranchesKey = 'cached_source_branches';
  static const _cachedDestinationTownsKey = 'cached_destination_towns';

  final SharedPreferences _preferences;

  static Future<AppPreferences> create() async {
    final preferences = await SharedPreferences.getInstance();
    return AppPreferences(preferences);
  }

  String? getCityCode() => _preferences.getString(_cityCodeKey);

  String? getAccountCode() => _preferences.getString(_accountCodeKey);

  String? getDeviceId() => _preferences.getString(_deviceIdKey);

  Future<bool> setCityCode(String value) {
    return _preferences.setString(_cityCodeKey, value);
  }

  Future<bool> setAccountCode(String value) {
    return _preferences.setString(_accountCodeKey, value);
  }

  Future<bool> setDeviceId(String value) {
    return _preferences.setString(_deviceIdKey, value);
  }

  String? getBusinessName() => _preferences.getString(_businessNameKey);

  String? getBusinessSubtitle() => _preferences.getString(_businessSubtitleKey);

  String? getBusinessAddress() => _preferences.getString(_businessAddressKey);

  String? getBusinessPhone() => _preferences.getString(_businessPhoneKey);

  double? getBusinessNameFontSize() {
    return _preferences.getDouble(_businessNameFontSizeKey);
  }

  double? getBusinessSubtitleFontSize() {
    return _preferences.getDouble(_businessSubtitleFontSizeKey);
  }

  double? getBusinessPhoneFontSize() {
    return _preferences.getDouble(_businessPhoneFontSizeKey);
  }

  double? getBusinessAddressFontSize() {
    return _preferences.getDouble(_businessAddressFontSizeKey);
  }

  double? getReceiptLabelFontSize() {
    return _preferences.getDouble(_receiptLabelFontSizeKey);
  }

  double? getReceiptValueFontSize() {
    return _preferences.getDouble(_receiptValueFontSizeKey);
  }

  double? getReceiptPaddingTop() {
    return _preferences.getDouble(_receiptPaddingTopKey);
  }

  double? getReceiptPaddingLeft() {
    return _preferences.getDouble(_receiptPaddingLeftKey);
  }

  double? getReceiptPaddingRight() {
    return _preferences.getDouble(_receiptPaddingRightKey);
  }

  double? getReceiptPaddingBottom() {
    return _preferences.getDouble(_receiptPaddingBottomKey);
  }

  String? getFooterMessage() => _preferences.getString(_footerMessageKey);

  String? getPrinterPreset() => _preferences.getString(_printerPresetKey);

  double? getLabelTitleFontSize() {
    return _preferences.getDouble(_labelTitleFontSizeKey);
  }

  double? getLabelSubtitleFontSize() {
    return _preferences.getDouble(_labelSubtitleFontSizeKey);
  }

  double? getLabelBodyFontSize() {
    return _preferences.getDouble(_labelBodyFontSizeKey);
  }

  double? getLabelPaddingTop() {
    return _preferences.getDouble(_labelPaddingTopKey);
  }

  double? getLabelPaddingHorizontal() {
    return _preferences.getDouble(_labelPaddingHorizontalKey);
  }

  double? getLabelRowGap() {
    return _preferences.getDouble(_labelRowGapKey);
  }

  String? getLastLabelPrinterId() {
    return _preferences.getString(_lastLabelPrinterIdKey);
  }

  String? getLastLabelPrinterName() {
    return _preferences.getString(_lastLabelPrinterNameKey);
  }

  DateTime? getParcelPullLastSyncedAt({required String scope}) {
    final value = _preferences.getString(_parcelPullCursorKey(scope));
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  Map<String, dynamic>? getCachedStaffProfile() {
    final value = _preferences.getString(_cachedStaffProfileKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> getCachedDestinationTowns() {
    final value = _preferences.getString(_cachedDestinationTownsKey);
    if (value == null || value.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<Map<String, dynamic>> getCachedSourceBranches() {
    final value = _preferences.getString(_cachedSourceBranchesKey);
    if (value == null || value.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> setBusinessName(String value) {
    return _preferences.setString(_businessNameKey, value);
  }

  Future<bool> setBusinessSubtitle(String value) {
    return _preferences.setString(_businessSubtitleKey, value);
  }

  Future<bool> setBusinessAddress(String value) {
    return _preferences.setString(_businessAddressKey, value);
  }

  Future<bool> setBusinessPhone(String value) {
    return _preferences.setString(_businessPhoneKey, value);
  }

  Future<bool> setBusinessNameFontSize(double value) {
    return _preferences.setDouble(_businessNameFontSizeKey, value);
  }

  Future<bool> setBusinessSubtitleFontSize(double value) {
    return _preferences.setDouble(_businessSubtitleFontSizeKey, value);
  }

  Future<bool> setBusinessPhoneFontSize(double value) {
    return _preferences.setDouble(_businessPhoneFontSizeKey, value);
  }

  Future<bool> setBusinessAddressFontSize(double value) {
    return _preferences.setDouble(_businessAddressFontSizeKey, value);
  }

  Future<bool> setReceiptLabelFontSize(double value) {
    return _preferences.setDouble(_receiptLabelFontSizeKey, value);
  }

  Future<bool> setReceiptValueFontSize(double value) {
    return _preferences.setDouble(_receiptValueFontSizeKey, value);
  }

  Future<bool> setReceiptPaddingTop(double value) {
    return _preferences.setDouble(_receiptPaddingTopKey, value);
  }

  Future<bool> setReceiptPaddingLeft(double value) {
    return _preferences.setDouble(_receiptPaddingLeftKey, value);
  }

  Future<bool> setReceiptPaddingRight(double value) {
    return _preferences.setDouble(_receiptPaddingRightKey, value);
  }

  Future<bool> setReceiptPaddingBottom(double value) {
    return _preferences.setDouble(_receiptPaddingBottomKey, value);
  }

  Future<bool> setFooterMessage(String value) {
    return _preferences.setString(_footerMessageKey, value);
  }

  Future<bool> setPrinterPreset(String value) {
    return _preferences.setString(_printerPresetKey, value);
  }

  Future<bool> setLabelTitleFontSize(double value) {
    return _preferences.setDouble(_labelTitleFontSizeKey, value);
  }

  Future<bool> setLabelSubtitleFontSize(double value) {
    return _preferences.setDouble(_labelSubtitleFontSizeKey, value);
  }

  Future<bool> setLabelBodyFontSize(double value) {
    return _preferences.setDouble(_labelBodyFontSizeKey, value);
  }

  Future<bool> setLabelPaddingTop(double value) {
    return _preferences.setDouble(_labelPaddingTopKey, value);
  }

  Future<bool> setLabelPaddingHorizontal(double value) {
    return _preferences.setDouble(_labelPaddingHorizontalKey, value);
  }

  Future<bool> setLabelRowGap(double value) {
    return _preferences.setDouble(_labelRowGapKey, value);
  }

  Future<bool> setLastLabelPrinter({
    required String id,
    required String name,
  }) async {
    final savedId = await _preferences.setString(_lastLabelPrinterIdKey, id);
    final savedName = await _preferences.setString(
      _lastLabelPrinterNameKey,
      name,
    );
    return savedId && savedName;
  }

  Future<bool> setParcelPullLastSyncedAt({
    required String scope,
    required DateTime value,
  }) {
    return _preferences.setString(
      _parcelPullCursorKey(scope),
      value.toUtc().toIso8601String(),
    );
  }

  String _parcelPullCursorKey(String scope) {
    return '${_parcelPullLastSyncedAtKey}_${scope.trim()}';
  }

  Future<bool> setCachedStaffProfile(Map<String, dynamic> value) {
    return _preferences.setString(_cachedStaffProfileKey, jsonEncode(value));
  }

  Future<bool> setCachedDestinationTowns(List<Map<String, dynamic>> value) {
    return _preferences.setString(
      _cachedDestinationTownsKey,
      jsonEncode(value),
    );
  }

  Future<bool> setCachedSourceBranches(List<Map<String, dynamic>> value) {
    return _preferences.setString(_cachedSourceBranchesKey, jsonEncode(value));
  }
}
