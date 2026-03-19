import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/parcel.dart';
import 'parcel_status_chip.dart';

class ParcelListItem extends StatelessWidget {
  const ParcelListItem({
    super.key,
    required this.parcel,
    required this.onTap,
  });

  final ParcelModel parcel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.large,
        child: Padding(
          padding: AppSpacing.listItemPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(parcel.trackingId, style: AppTextStyles.subtitle),
              const SizedBox(height: AppSpacing.xs),
              Text(parcel.receiverName, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.xs),
              Text(parcel.receiverPhone, style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppDateUtils.formatDateTime(parcel.createdAt),
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.sm),
              ParcelStatusChip(status: parcel.status.value),
            ],
          ),
        ),
      ),
    );
  }
}
