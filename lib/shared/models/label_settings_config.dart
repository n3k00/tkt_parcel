class LabelSizePreset {
  const LabelSizePreset({
    required this.id,
    required this.label,
    required this.widthMm,
    required this.heightMm,
    required this.widthPx,
    required this.heightPx,
  });

  static const mm75x50 = LabelSizePreset(
    id: '75x50',
    label: '75 x 50 mm',
    widthMm: 75,
    heightMm: 50,
    widthPx: 600,
    heightPx: 400,
  );

  static const mm80x60 = LabelSizePreset(
    id: '80x60',
    label: '80 x 60 mm',
    widthMm: 80,
    heightMm: 60,
    widthPx: 640,
    heightPx: 480,
  );

  static const values = [mm75x50, mm80x60];

  final String id;
  final String label;
  final double widthMm;
  final double heightMm;
  final int widthPx;
  final int heightPx;

  double get aspectRatio => widthMm / heightMm;

  static LabelSizePreset fromId(String? id) {
    final normalized = id?.trim().toLowerCase();
    for (final preset in values) {
      if (preset.id == normalized) {
        return preset;
      }
    }
    return mm75x50;
  }
}

class LabelSettingsConfig {
  const LabelSettingsConfig({
    required this.labelSize,
    required this.titleFontSize,
    required this.subtitleFontSize,
    required this.bodyFontSize,
    required this.paddingTop,
    required this.paddingHorizontal,
    required this.rowGap,
  });

  final LabelSizePreset labelSize;
  final double titleFontSize;
  final double subtitleFontSize;
  final double bodyFontSize;
  final double paddingTop;
  final double paddingHorizontal;
  final double rowGap;

  LabelSettingsConfig copyWith({
    LabelSizePreset? labelSize,
    double? titleFontSize,
    double? subtitleFontSize,
    double? bodyFontSize,
    double? paddingTop,
    double? paddingHorizontal,
    double? rowGap,
  }) {
    return LabelSettingsConfig(
      labelSize: labelSize ?? this.labelSize,
      titleFontSize: titleFontSize ?? this.titleFontSize,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      paddingTop: paddingTop ?? this.paddingTop,
      paddingHorizontal: paddingHorizontal ?? this.paddingHorizontal,
      rowGap: rowGap ?? this.rowGap,
    );
  }
}
