import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  int? _savedParcelId;

  Future<int> _ensureParcelSaved(VoucherPreviewData preview) async {
    if (_savedParcelId != null) {
      return _savedParcelId!;
    }

    final parcelId = await ref
        .read(parcelRepositoryProvider)
        .createParcel(preview.parcel);
    setState(() {
      _savedParcelId = parcelId;
    });
    return parcelId;
  }

  Future<void> _handleConfirmAndPrint(VoucherPreviewData preview) async {
    final printerNotifier = ref.read(printerStateProvider.notifier);
    final printerState = ref.read(printerStateProvider);

    if (!printerState.isConnected) {
      await Navigator.of(context).pushNamed(PrinterConnectScreen.routeName);
      if (!mounted || !ref.read(printerStateProvider).isConnected) {
        return;
      }
    }

    final parcelId = await _ensureParcelSaved(preview);
    final imageBytes = await ref
        .read(printServiceProvider)
        .captureWidgetAsPng(_printBoundaryKey);
    final success = await printerNotifier.printImageBytes(imageBytes);

    if (!mounted) {
      return;
    }

    await ref.read(parcelFormProvider.notifier).reset();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Parcel #$parcelId printed successfully.'
              : ref.read(printerStateProvider).errorMessage ??
                    'Parcel #$parcelId was saved locally, but voucher print failed.',
        ),
      ),
    );
  }

  Future<void> _handleConfirmOnly(VoucherPreviewData preview) async {
    final parcelId = await _ensureParcelSaved(preview);
    if (!mounted) {
      return;
    }

    await ref.read(parcelFormProvider.notifier).reset();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Parcel #$parcelId saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final previewAsync = ref.watch(voucherPreviewProvider(widget.args));
    final printerState = ref.watch(printerStateProvider);

    return AppScaffold(
      title: 'Voucher Preview',
      body: previewAsync.when(
        data: (preview) => ListView(
          padding: AppSpacing.screenPadding,
          children: [
            Offstage(
              offstage: true,
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
            const SizedBox(height: AppSpacing.md),
            VoucherCard(
              parcel: preview.parcel,
              qrPayload: preview.qrPayload,
              setup: preview.setup,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              printerState.isConnected
                  ? 'Printer: ${printerState.connectedPrinterName}'
                  : 'No printer connected.',
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: printerState.isBusy
                  ? null
                  : () => _handleConfirmAndPrint(preview),
              child: Text(
                printerState.isConnected
                    ? 'Confirm and Print'
                    : 'Connect and Print',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: _savedParcelId == null
                  ? () => _handleConfirmOnly(preview)
                  : null,
              child: Text(
                _savedParcelId == null
                    ? 'Confirm Without Print'
                    : 'Parcel Saved',
              ),
            ),
            if (printerState.errorMessage != null &&
                printerState.lastPrintableImageBytes != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: printerState.isBusy
                    ? null
                    : () => ref
                          .read(printerStateProvider.notifier)
                          .retryLastPrint(),
                child: const Text('Retry Print'),
              ),
            ],
            if (printerState.lastPrintableImageBytes != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: printerState.isBusy
                    ? null
                    : () => ref
                          .read(printerStateProvider.notifier)
                          .reprintLastVoucher(),
                child: const Text('Reprint Last Voucher'),
              ),
            ],
          ],
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
