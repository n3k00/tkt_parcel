import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/layout/app_responsive.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../providers/printer_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../parcel/presentation/screens/home_screen.dart';
import '../../../printer/presentation/screens/printer_settings_screen.dart';
import '../providers/settings_provider.dart';
import 'receipt_settings_screen.dart';
import 'staff_account_info_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsData = ref.watch(settingsDataProvider);
    final printerState = ref.watch(printerStateProvider);

    return AppScaffold(
      title: 'Settings',
      drawer: const AppDrawer(currentRoute: SettingsScreen.routeName),
      canPop: false,
      onBackNavigation: () {
        Navigator.of(context).pushReplacementNamed(HomeScreen.routeName);
      },
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
      ),
      body: settingsData.when(
        data: (data) {
          final setup = data.setup;
          final appInfo = data.appInfo;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isExpanded = constraints.maxWidth >= AppBreakpoints.medium;
              final contentWidth = AppResponsive.centeredContentWidth(
                context,
                horizontalPadding: AppSpacing.lg,
              );
              final cards = [
                _SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Staff Setup', style: AppTextStyles.title),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Local counter setup values used for offline voucher creation and tracking ID generation.',
                        style: AppTextStyles.bodyMuted,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _SummaryRow(label: 'City Code', value: setup.cityCode),
                      const Divider(),
                      _SummaryRow(
                        label: 'Account Code',
                        value: setup.accountCode,
                      ),
                      const Divider(),
                      _SummaryRow(
                        label: 'Address',
                        value: setup.businessAddress,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pushNamed(StaffAccountInfoScreen.routeName);
                          },
                          icon: const Icon(Icons.badge_outlined),
                          label: const Text('Edit Staff Account Info'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pushNamed(ReceiptSettingsScreen.routeName);
                          },
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Open Receipt Settings'),
                        ),
                      ),
                    ],
                  ),
                ),
                _SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Printer', style: AppTextStyles.title),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        printerState.connectedPrinterName ??
                            'No printer connected',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        printerState.connectionMessage,
                        style: AppTextStyles.bodyMuted,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pushNamed(PrinterSettingsScreen.routeName);
                          },
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Open Printer Settings'),
                        ),
                      ),
                    ],
                  ),
                ),
                _SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('App Version', style: AppTextStyles.title),
                      const SizedBox(height: AppSpacing.lg),
                      _SummaryRow(label: 'App Name', value: appInfo.appName),
                      const Divider(),
                      _SummaryRow(
                        label: 'Version',
                        value: appInfo.versionLabel,
                      ),
                      const Divider(),
                      _SummaryRow(label: 'Package', value: appInfo.packageName),
                    ],
                  ),
                ),
              ];

              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: contentWidth,
                  child: ListView(
                    padding: AppSpacing.screenPadding,
                    children: [
                      if (isExpanded)
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: cards
                              .map(
                                (card) => SizedBox(
                                  width: (contentWidth - AppSpacing.md) / 2,
                                  child: card,
                                ),
                              )
                              .toList(),
                        )
                      else
                        ...cards.expand(
                          (card) => [card, const SizedBox(height: AppSpacing.md)],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: AppLoading.new,
        error: (error, _) => AppErrorView(message: error.toString()),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: child,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}
