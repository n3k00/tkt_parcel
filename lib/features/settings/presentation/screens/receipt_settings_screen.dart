import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/voucher_layout.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/models/enums/payment_status.dart';
import '../../../../data/models/parcel.dart';
import '../../../../shared/models/app_setup_config.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../voucher/presentation/widgets/voucher_card.dart';
import '../providers/settings_provider.dart';

class ReceiptSettingsScreen extends ConsumerStatefulWidget {
  const ReceiptSettingsScreen({super.key});

  static const routeName = '/settings/receipt';

  @override
  ConsumerState<ReceiptSettingsScreen> createState() =>
      _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends ConsumerState<ReceiptSettingsScreen> {
  AppSetupConfig? _draft;

  @override
  Widget build(BuildContext context) {
    final setupAsync = ref.watch(settingsSetupProvider);

    return AppScaffold(
      title: 'Receipt Settings',
      body: setupAsync.when(
        data: (setup) {
          _draft ??= setup;
          final draft = _draft!;
          final sampleParcel = ParcelModel.create(
            trackingId: 'TGI-A1-260319-0003',
            fromTown: 'တောင်ကြီး',
            toTown: 'တာချီလိတ်',
            cityCode: 'TGI',
            accountCode: 'A1',
            senderName: 'နန္ဒာလှ',
            senderPhone: '52388',
            receiverName: 'မအမာ',
            receiverPhone: '8368',
            parcelType: 'အကြီး',
            numberOfParcels: 255,
            totalCharges: 5586,
            paymentStatus: PaymentStatus.unpaid,
            cashAdvance: 5,
            now: DateTime(2026, 3, 19, 18, 23),
          );

          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              SectionCard(
                child: Padding(
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Preview',
                        style: AppTextStyles.title,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final previewWidth = math.min(
                            constraints.maxWidth,
                            VoucherLayout.previewPaperWidth,
                          );
                          return Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: previewWidth),
                              child: FittedBox(
                                fit: BoxFit.contain,
                                alignment: Alignment.topCenter,
                                child: VoucherCard(
                                  parcel: sampleParcel,
                                  qrPayload: 'TRACK:TGI-A1-260319-0003',
                                  setup: draft,
                                  isPrintable: true,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                child: Padding(
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Header Font Size',
                        style: AppTextStyles.title,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SliderField(
                        label: 'Title',
                        value: draft.businessNameFontSize,
                        min: 18,
                        max: 80,
                        onChanged: (value) => setState(() {
                          _draft = draft.copyWith(businessNameFontSize: value);
                        }),
                      ),
                      _SliderField(
                        label: 'Subtitle',
                        value: draft.businessSubtitleFontSize,
                        min: 12,
                        max: 40,
                        onChanged: (value) => setState(() {
                          _draft = draft.copyWith(
                            businessSubtitleFontSize: value,
                          );
                        }),
                      ),
                      _SliderField(
                        label: 'Phone',
                        value: draft.businessPhoneFontSize,
                        min: 10,
                        max: 32,
                        onChanged: (value) => setState(() {
                          _draft = draft.copyWith(businessPhoneFontSize: value);
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                child: Padding(
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Body Font Size',
                        style: AppTextStyles.title,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SliderField(
                        label: 'Label',
                        value: draft.receiptLabelFontSize,
                        min: 14,
                        max: 40,
                        onChanged: (value) => setState(() {
                          _draft = draft.copyWith(receiptLabelFontSize: value);
                        }),
                      ),
                      _SliderField(
                        label: 'Value',
                        value: draft.receiptValueFontSize,
                        min: 14,
                        max: 44,
                        onChanged: (value) => setState(() {
                          _draft = draft.copyWith(receiptValueFontSize: value);
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                child: Padding(
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Receipt Padding',
                        style: AppTextStyles.title,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SliderField(
                        label: 'Top',
                        value: draft.receiptPaddingTop,
                        min: 0,
                        max: 60,
                        onChanged: (value) => setState(() {
                          _draft = draft.copyWith(receiptPaddingTop: value);
                        }),
                      ),
                      _SliderField(
                        label: 'Horizontal',
                        value: draft.receiptPaddingLeft,
                        min: 0,
                        max: 40,
                        onChanged: (value) => setState(() {
                          _draft = draft.copyWith(
                            receiptPaddingLeft: value,
                            receiptPaddingRight: value,
                          );
                        }),
                      ),
                      _SliderField(
                        label: 'Bottom',
                        value: draft.receiptPaddingBottom,
                        min: 0,
                        max: 80,
                        onChanged: (value) => setState(() {
                          _draft = draft.copyWith(receiptPaddingBottom: value);
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await ref.read(settingsSetupProvider.notifier).saveSetup(draft);
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Receipt settings saved.')),
                  );
                },
                child: const Text('Save Receipt Settings'),
              ),
            ],
          );
        },
        loading: AppLoading.new,
        error: (error, _) => AppErrorView(message: error.toString()),
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(min, max).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppTextStyles.label)),
              Text(clampedValue.toStringAsFixed(0), style: AppTextStyles.body),
            ],
          ),
          Slider(
            value: clampedValue,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
