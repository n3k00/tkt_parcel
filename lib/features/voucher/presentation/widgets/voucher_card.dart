import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/parcel.dart';
import '../../../../shared/models/app_setup_config.dart';
import 'voucher_qr_view.dart';

class VoucherCard extends StatelessWidget {
  const VoucherCard({
    super.key,
    required this.parcel,
    required this.qrPayload,
    required this.setup,
    this.isPrintable = false,
  });

  final ParcelModel parcel;
  final String qrPayload;
  final AppSetupConfig setup;
  final bool isPrintable;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(setup.businessName, style: AppTextStyles.title, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              setup.businessSubtitle,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              setup.businessPhone,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Created: ${AppDateUtils.formatDateTime(parcel.createdAt)}',
                style: AppTextStyles.body,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Tracking ID: ${parcel.trackingId}', style: AppTextStyles.subtitle),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Route: ${parcel.fromTown} / ${parcel.toTown}',
                style: AppTextStyles.body,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sender: ${parcel.senderName} / ${parcel.senderPhone}',
                style: AppTextStyles.body,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Receiver: ${parcel.receiverName} / ${parcel.receiverPhone}',
                style: AppTextStyles.body,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Parcel Type: ${parcel.parcelType}', style: AppTextStyles.body),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Number of Parcels: ${parcel.numberOfParcels}',
                style: AppTextStyles.body,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Total Charges: ${parcel.totalCharges.toStringAsFixed(0)}',
                style: AppTextStyles.body,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Payment Status: ${parcel.paymentStatus.value.toUpperCase()}',
                style: AppTextStyles.body,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Cash Advance: ${parcel.cashAdvance.toStringAsFixed(0)}',
                style: AppTextStyles.body,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Remark: ${parcel.remark ?? '-'}',
                style: AppTextStyles.body,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Center(child: VoucherQrView(payload: qrPayload)),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Thank you for choosing TKT Parcel.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            if ((setup.footerMessage ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                setup.footerMessage!,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );

    if (isPrintable) {
      return ColoredBox(
        color: Colors.white,
        child: SizedBox(
          width: 384,
          child: content,
        ),
      );
    }

    return Card(
      child: content,
    );
  }
}
