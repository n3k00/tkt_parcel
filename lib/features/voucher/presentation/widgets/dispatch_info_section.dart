import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/parcel.dart';

class DispatchInfoSection extends StatelessWidget {
  const DispatchInfoSection({super.key, required this.parcel});

  final ParcelModel parcel;

  bool get hasDispatchInfo {
    return _hasText(parcel.driverName) ||
        _hasText(parcel.driverPhone) ||
        parcel.dispatchedDate != null ||
        parcel.dispatchedAt != null ||
        _hasText(parcel.claimNote) ||
        parcel.status.value != 'received';
  }

  @override
  Widget build(BuildContext context) {
    if (!hasDispatchInfo) {
      return const SizedBox.shrink();
    }

    final dispatchedDate = parcel.dispatchedDate ?? parcel.dispatchedAt;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.large,
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dispatch Info',
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_hasText(parcel.driverName))
                _InfoRow(label: 'Driver', value: parcel.driverName!),
              if (_hasText(parcel.driverPhone))
                _InfoRow(label: 'Driver Phone', value: parcel.driverPhone!),
              if (dispatchedDate != null)
                _InfoRow(
                  label: 'Dispatched Date',
                  value: AppDateUtils.formatDateTime12Hour(dispatchedDate),
                ),
              _InfoRow(label: 'Dispatch Status', value: parcel.status.value),
              if (_hasText(parcel.claimNote))
                _InfoRow(label: 'Claim Note', value: parcel.claimNote!),
            ],
          ),
        ),
      ),
    );
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
