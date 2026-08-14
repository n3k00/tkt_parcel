import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ParcelStatusChip extends StatelessWidget {
  const ParcelStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'received' => AppColors.received,
      'partially_split' => AppColors.partiallySplit,
      'dispatched' => AppColors.dispatched,
      'arrived' => AppColors.arrived,
      'claimed' => AppColors.claimed,
      'split' => AppColors.split,
      'cancelled' => AppColors.cancelled,
      _ => AppColors.textSecondary,
    };

    final label = switch (status) {
      'partially_split' => 'PARTIALLY SPLIT',
      _ => status.toUpperCase(),
    };

    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.18)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }
}
