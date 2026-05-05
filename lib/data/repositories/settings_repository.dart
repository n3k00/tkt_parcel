import '../../core/constants/receipt_strings.dart';
import '../../shared/models/label_settings_config.dart';
import '../../shared/models/label_printer_selection.dart';
import '../../shared/models/app_setup_config.dart';
import '../local/preferences/app_preferences.dart';

class SettingsRepository {
  SettingsRepository(this._preferences);

  static const _defaultCityCode = 'TGI';
  static const _defaultAccountCode = 'A1';
  static const _defaultBusinessName = ReceiptStrings.defaultBusinessName;
  static const _defaultBusinessSubtitle = ReceiptStrings.defaultBusinessSubtitle;
  static const _defaultBusinessAddress = ReceiptStrings.defaultBusinessAddress;
  static const _defaultBusinessPhone = ReceiptStrings.defaultBusinessPhone;
  static const _defaultBusinessNameFontSize = 60.0;
  static const _defaultBusinessSubtitleFontSize = 26.0;
  static const _defaultBusinessAddressFontSize = 22.0;
  static const _defaultBusinessPhoneFontSize = 20.0;
  static const _defaultReceiptLabelFontSize = 28.0;
  static const _defaultReceiptValueFontSize = 30.0;
  static const _defaultReceiptPaddingTop = 20.0;
  static const _defaultReceiptPaddingLeft = 24.0;
  static const _defaultReceiptPaddingRight = 24.0;
  static const _defaultReceiptPaddingBottom = 40.0;
  static const _defaultFooterMessage = ReceiptStrings.defaultFooter;
  static const _defaultPrinterPreset = 'balanced';
  static const _defaultLabelTitleFontSize = 78.0;
  static const _defaultLabelSubtitleFontSize = 30.0;
  static const _defaultLabelBodyFontSize = 42.0;
  static const _defaultLabelPaddingTop = 28.0;
  static const _defaultLabelPaddingHorizontal = 28.0;
  static const _defaultLabelRowGap = 18.0;

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
      businessAddress:
          _preferences.getBusinessAddress() ?? _defaultBusinessAddress,
      businessPhone: _preferences.getBusinessPhone() ?? _defaultBusinessPhone,
      businessNameFontSize:
          _preferences.getBusinessNameFontSize() ?? _defaultBusinessNameFontSize,
      businessSubtitleFontSize:
          _preferences.getBusinessSubtitleFontSize() ??
          _defaultBusinessSubtitleFontSize,
      businessAddressFontSize:
          _preferences.getBusinessAddressFontSize() ??
          _defaultBusinessAddressFontSize,
      businessPhoneFontSize:
          _preferences.getBusinessPhoneFontSize() ??
          _defaultBusinessPhoneFontSize,
      receiptLabelFontSize:
          _preferences.getReceiptLabelFontSize() ?? _defaultReceiptLabelFontSize,
      receiptValueFontSize:
          _preferences.getReceiptValueFontSize() ?? _defaultReceiptValueFontSize,
      receiptPaddingTop:
          _preferences.getReceiptPaddingTop() ?? _defaultReceiptPaddingTop,
      receiptPaddingLeft:
          _preferences.getReceiptPaddingLeft() ?? _defaultReceiptPaddingLeft,
      receiptPaddingRight:
          _preferences.getReceiptPaddingRight() ?? _defaultReceiptPaddingRight,
      receiptPaddingBottom:
          _preferences.getReceiptPaddingBottom() ?? _defaultReceiptPaddingBottom,
      footerMessage: _preferences.getFooterMessage() ?? _defaultFooterMessage,
    );
  }

  Future<void> saveAppSetup(AppSetupConfig config) async {
    await _preferences.setCityCode(config.cityCode.toUpperCase());
    await _preferences.setAccountCode(config.accountCode.toUpperCase());
    await _preferences.setBusinessName(config.businessName.trim());
    await _preferences.setBusinessSubtitle(config.businessSubtitle.trim());
    await _preferences.setBusinessAddress(config.businessAddress.trim());
    await _preferences.setBusinessPhone(config.businessPhone.trim());
    await _preferences.setBusinessNameFontSize(config.businessNameFontSize);
    await _preferences.setBusinessSubtitleFontSize(
      config.businessSubtitleFontSize,
    );
    await _preferences.setBusinessAddressFontSize(config.businessAddressFontSize);
    await _preferences.setBusinessPhoneFontSize(config.businessPhoneFontSize);
    await _preferences.setReceiptLabelFontSize(config.receiptLabelFontSize);
    await _preferences.setReceiptValueFontSize(config.receiptValueFontSize);
    await _preferences.setReceiptPaddingTop(config.receiptPaddingTop);
    await _preferences.setReceiptPaddingLeft(config.receiptPaddingLeft);
    await _preferences.setReceiptPaddingRight(config.receiptPaddingRight);
    await _preferences.setReceiptPaddingBottom(config.receiptPaddingBottom);
    await _preferences.setFooterMessage((config.footerMessage ?? '').trim());
  }

  Future<String?> getDefaultSourceTownName() async {
    final townName = _preferences.getDefaultSourceTownName();
    if (townName == null || townName.trim().isEmpty) {
      return null;
    }
    return townName.trim();
  }

  Future<void> saveDefaultSourceTownName(String townName) async {
    await _preferences.setDefaultSourceTownName(townName.trim());
  }

  Future<String> getPrinterPreset() async {
    final preset = _preferences.getPrinterPreset();
    if (preset == null || preset.trim().isEmpty) {
      return _defaultPrinterPreset;
    }
    return preset.trim().toLowerCase();
  }

  Future<void> savePrinterPreset(String preset) async {
    await _preferences.setPrinterPreset(preset.trim().toLowerCase());
  }

  Future<LabelSettingsConfig> getLabelSettings() async {
    return LabelSettingsConfig(
      titleFontSize: _normalizeLabelValue(
        _preferences.getLabelTitleFontSize(),
        fallback: _defaultLabelTitleFontSize,
        min: 52,
        max: 110,
      ),
      subtitleFontSize: _normalizeLabelValue(
        _preferences.getLabelSubtitleFontSize(),
        fallback: _defaultLabelSubtitleFontSize,
        min: 22,
        max: 52,
      ),
      bodyFontSize: _normalizeLabelValue(
        _preferences.getLabelBodyFontSize(),
        fallback: _defaultLabelBodyFontSize,
        min: 30,
        max: 64,
      ),
      paddingTop: _normalizeLabelValue(
        _preferences.getLabelPaddingTop(),
        fallback: _defaultLabelPaddingTop,
        min: 10,
        max: 80,
      ),
      paddingHorizontal: _normalizeLabelValue(
        _preferences.getLabelPaddingHorizontal(),
        fallback: _defaultLabelPaddingHorizontal,
        min: 8,
        max: 80,
      ),
      rowGap: _normalizeLabelValue(
        _preferences.getLabelRowGap(),
        fallback: _defaultLabelRowGap,
        min: 8,
        max: 40,
      ),
    );
  }

  Future<void> saveLabelSettings(LabelSettingsConfig config) async {
    await _preferences.setLabelTitleFontSize(config.titleFontSize);
    await _preferences.setLabelSubtitleFontSize(config.subtitleFontSize);
    await _preferences.setLabelBodyFontSize(config.bodyFontSize);
    await _preferences.setLabelPaddingTop(config.paddingTop);
    await _preferences.setLabelPaddingHorizontal(config.paddingHorizontal);
    await _preferences.setLabelRowGap(config.rowGap);
  }

  Future<LabelPrinterSelection?> getLastLabelPrinter() async {
    final id = _preferences.getLastLabelPrinterId();
    final name = _preferences.getLastLabelPrinterName();
    if (id == null || id.trim().isEmpty || name == null || name.trim().isEmpty) {
      return null;
    }
    return LabelPrinterSelection(id: id.trim(), name: name.trim());
  }

  Future<void> saveLastLabelPrinter(LabelPrinterSelection printer) async {
    await _preferences.setLastLabelPrinter(
      id: printer.id.trim(),
      name: printer.name.trim(),
    );
  }

  double _normalizeLabelValue(
    double? value, {
    required double fallback,
    required double min,
    required double max,
  }) {
    return (value ?? fallback).clamp(min, max).toDouble();
  }
}
