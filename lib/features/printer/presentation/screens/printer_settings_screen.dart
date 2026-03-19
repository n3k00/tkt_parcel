import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../providers/printer_provider.dart';
import '../../../../shared/helpers/printer_connect_navigation.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/section_card.dart';

class PrinterSettingsScreen extends ConsumerWidget {
  const PrinterSettingsScreen({super.key});

  static const routeName = '/settings/printer';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printerState = ref.watch(printerStateProvider);
    final printerNotifier = ref.read(printerStateProvider.notifier);

    return AppScaffold(
      title: 'Printer Settings',
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          SectionCard(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Connection Status', style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.md),
                  _StatusLine(
                    label: 'Bluetooth',
                    value: printerState.isBluetoothOn ? 'On' : 'Off',
                    valueColor: printerState.isBluetoothOn
                        ? AppColors.success
                        : AppColors.error,
                  ),
                  const Divider(),
                  _StatusLine(
                    label: 'Status',
                    value: printerState.connectionMessage,
                  ),
                  const Divider(),
                  _StatusLine(
                    label: 'Connected Printer',
                    value: printerState.connectedPrinterName ?? 'Not connected',
                    valueColor: printerState.isConnected
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                  if (printerState.errorMessage != null) ...[
                    const Divider(),
                    _StatusLine(
                      label: 'Last Error',
                      value: printerState.errorMessage!,
                      valueColor: AppColors.error,
                    ),
                  ],
                  if (printerState.printProgress != null) ...[
                    const Divider(),
                    _StatusLine(
                      label: 'Print Progress',
                      value: printerState.printProgress!.stage.name,
                    ),
                  ],
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
                  const Text('Printer Actions', style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Use the plugin connect page to pair or switch printers. Test print can be used after a printer is connected.',
                    style: AppTextStyles.bodyMuted,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        openPrinterConnectPage(context, ref);
                      },
                      icon: const Icon(Icons.bluetooth_searching),
                      label: const Text('Open Printer Connect Page'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: printerState.isConnected
                          ? () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await printerNotifier.disconnect();
                              if (!context.mounted) {
                                return;
                              }
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Printer disconnected.'),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Disconnect Printer'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          printerState.isConnected && !printerState.isBusy
                          ? () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final success = await printerNotifier.testPrint();
                              if (!context.mounted) {
                                return;
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Test print sent to printer.'
                                        : printerState.errorMessage ??
                                              'Test print failed.',
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.print),
                      label: const Text('Run Test Print'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.label)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.body.copyWith(
                color: valueColor ?? AppTextStyles.body.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
