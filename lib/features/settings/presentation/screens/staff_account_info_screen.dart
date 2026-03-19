import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/section_card.dart';
import '../providers/settings_provider.dart';

class StaffAccountInfoScreen extends ConsumerWidget {
  const StaffAccountInfoScreen({super.key});

  static const routeName = '/settings/staff-account';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsData = ref.watch(settingsDataProvider);

    return AppScaffold(
      title: 'Staff Account Info',
      body: settingsData.when(
        data: (data) {
          final setup = data.setup;
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
                        'Local Counter Setup',
                        style: AppTextStyles.title,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Account code and city code are read-only in this phase to keep tracking ID generation consistent on this device.',
                        style: AppTextStyles.bodyMuted,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _InfoRow(
                        label: 'Business Name',
                        value: setup.businessName,
                      ),
                      const Divider(),
                      _InfoRow(
                        label: 'Business Subtitle',
                        value: setup.businessSubtitle,
                      ),
                      const Divider(),
                      _InfoRow(
                        label: 'Business Phone',
                        value: setup.businessPhone,
                      ),
                      const Divider(),
                      _InfoRow(label: 'City Code', value: setup.cityCode),
                      const Divider(),
                      _InfoRow(label: 'Account Code', value: setup.accountCode),
                    ],
                  ),
                ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTextStyles.label)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}
