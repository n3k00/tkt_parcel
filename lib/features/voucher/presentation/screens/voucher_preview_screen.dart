import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/voucher_layout.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../providers/parcel_repository_provider.dart';
import '../../../../providers/printer_provider.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../parcel/presentation/providers/parcel_form_provider.dart';
import '../../../printing/presentation/screens/printer_connect_screen.dart';
import '../models/voucher_preview_args.dart';
import '../providers/voucher_preview_provider.dart';
import '../widgets/voucher_card.dart';

class VoucherPreviewScreen extends ConsumerStatefulWidget {
  const VoucherPreviewScreen({super.key, required this.args});

  static const routeName = '/voucher/preview';

  final VoucherPreviewArgs args;

  @override
  ConsumerState<VoucherPreviewScreen> createState() =>
      _VoucherPreviewScreenState();
}

class _VoucherPreviewScreenState extends ConsumerState<VoucherPreviewScreen> {
  final GlobalKey _printBoundaryKey = GlobalKey();

  Future<void> _handlePrintAndSave(VoucherPreviewData preview) async {
    final printerNotifier = ref.read(printerStateProvider.notifier);
    final printerState = ref.read(printerStateProvider);

    if (!printerState.isConnected) {
      await Navigator.of(context).pushNamed(PrinterConnectScreen.routeName);
      if (!mounted || !ref.read(printerStateProvider).isConnected) {
        return;
      }
    }

    final imageBytes = await ref
        .read(printServiceProvider)
        .captureWidgetAsPng(_printBoundaryKey);
    final success = await printerNotifier.printImageBytes(imageBytes);

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(printerStateProvider).errorMessage ??
                'Voucher print failed. Parcel was not saved.',
          ),
        ),
      );
      return;
    }

    final parcelId = await ref
        .read(parcelRepositoryProvider)
        .createParcel(preview.parcel);
    if (!mounted) {
      return;
    }

    await ref.read(parcelFormProvider.notifier).reset();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Parcel #$parcelId printed and saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewAsync = ref.watch(voucherPreviewProvider(widget.args));
    final printerState = ref.watch(printerStateProvider);

    return AppScaffold(
      title: 'Voucher Preview',
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: math.max(
          0.0,
          MediaQuery.sizeOf(context).width - (AppSpacing.lg * 2),
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
          ),
          onPressed: previewAsync.isLoading || printerState.isBusy
              ? null
              : () {
                  final preview = previewAsync.asData?.value;
                  if (preview != null) {
                    _handlePrintAndSave(preview);
                  }
                },
          child: const Text('Print and Save'),
        ),
      ),
      body: previewAsync.when(
        data: (preview) => LayoutBuilder(
          builder: (context, constraints) {
            final previewWidth = math.min(
              constraints.maxWidth,
              VoucherLayout.previewPaperWidth,
            );
            return ListView(
              padding: AppSpacing.screenPadding,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: previewWidth,
                    ),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.topCenter,
                      child: RepaintBoundary(
                        key: _printBoundaryKey,
                        child: VoucherCard(
                          parcel: preview.parcel,
                          qrPayload: preview.qrPayload,
                          setup: preview.setup,
                          isPrintable: true,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 104),
              ],
            );
          },
        ),
        loading: () => const Padding(
          padding: AppSpacing.screenPadding,
          child: AppLoading(),
        ),
        error: (error, _) => Padding(
          padding: AppSpacing.screenPadding,
          child: AppErrorView(message: error.toString()),
        ),
      ),
    );
  }
}
