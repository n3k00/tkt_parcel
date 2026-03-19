class AppSetupConfig {
  const AppSetupConfig({
    required this.cityCode,
    required this.accountCode,
    required this.businessName,
    required this.businessSubtitle,
    required this.businessPhone,
    this.footerMessage,
  });

  final String cityCode;
  final String accountCode;
  final String businessName;
  final String businessSubtitle;
  final String businessPhone;
  final String? footerMessage;

  AppSetupConfig copyWith({
    String? cityCode,
    String? accountCode,
    String? businessName,
    String? businessSubtitle,
    String? businessPhone,
    String? footerMessage,
    bool clearFooterMessage = false,
  }) {
    return AppSetupConfig(
      cityCode: cityCode ?? this.cityCode,
      accountCode: accountCode ?? this.accountCode,
      businessName: businessName ?? this.businessName,
      businessSubtitle: businessSubtitle ?? this.businessSubtitle,
      businessPhone: businessPhone ?? this.businessPhone,
      footerMessage:
          clearFooterMessage ? null : footerMessage ?? this.footerMessage,
    );
  }
}
