class LabelSettingsConfig {
  const LabelSettingsConfig({
    required this.titleFontSize,
    required this.subtitleFontSize,
    required this.bodyFontSize,
    required this.paddingTop,
    required this.paddingHorizontal,
    required this.rowGap,
  });

  final double titleFontSize;
  final double subtitleFontSize;
  final double bodyFontSize;
  final double paddingTop;
  final double paddingHorizontal;
  final double rowGap;

  LabelSettingsConfig copyWith({
    double? titleFontSize,
    double? subtitleFontSize,
    double? bodyFontSize,
    double? paddingTop,
    double? paddingHorizontal,
    double? rowGap,
  }) {
    return LabelSettingsConfig(
      titleFontSize: titleFontSize ?? this.titleFontSize,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      paddingTop: paddingTop ?? this.paddingTop,
      paddingHorizontal: paddingHorizontal ?? this.paddingHorizontal,
      rowGap: rowGap ?? this.rowGap,
    );
  }
}
