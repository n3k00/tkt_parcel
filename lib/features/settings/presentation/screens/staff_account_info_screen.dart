import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/app_setup_config.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/section_card.dart';
import '../providers/settings_provider.dart';

class StaffAccountInfoScreen extends ConsumerStatefulWidget {
  const StaffAccountInfoScreen({super.key});

  static const routeName = '/settings/staff-account';

  @override
  ConsumerState<StaffAccountInfoScreen> createState() =>
      _StaffAccountInfoScreenState();
}

class _StaffAccountInfoScreenState
    extends ConsumerState<StaffAccountInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _businessSubtitleController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _titleSizeController = TextEditingController();
  final _subtitleSizeController = TextEditingController();
  final _phoneSizeController = TextEditingController();

  bool _didSeedControllers = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessSubtitleController.dispose();
    _businessAddressController.dispose();
    _businessPhoneController.dispose();
    _titleSizeController.dispose();
    _subtitleSizeController.dispose();
    _phoneSizeController.dispose();
    super.dispose();
  }

  void _seedControllers(AppSetupConfig setup) {
    if (_didSeedControllers) {
      return;
    }

    _businessNameController.text = setup.businessName;
    _businessSubtitleController.text = setup.businessSubtitle;
    _businessAddressController.text = setup.businessAddress;
    _businessPhoneController.text = setup.businessPhone;
    _titleSizeController.text = setup.businessNameFontSize.toStringAsFixed(0);
    _subtitleSizeController.text = setup.businessSubtitleFontSize
        .toStringAsFixed(0);
    _phoneSizeController.text = setup.businessPhoneFontSize.toStringAsFixed(0);
    _didSeedControllers = true;
  }

  Future<void> _save(AppSetupConfig currentSetup) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final nextSetup = currentSetup.copyWith(
      businessName: _businessNameController.text.trim(),
      businessSubtitle: _businessSubtitleController.text.trim(),
      businessAddress: _businessAddressController.text.trim(),
      businessPhone: _businessPhoneController.text.trim(),
      businessNameFontSize: double.parse(_titleSizeController.text.trim()),
      businessSubtitleFontSize: double.parse(
        _subtitleSizeController.text.trim(),
      ),
      businessPhoneFontSize: double.parse(_phoneSizeController.text.trim()),
    );

    await ref.read(settingsSetupProvider.notifier).saveSetup(nextSetup);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voucher header settings saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final setupAsync = ref.watch(settingsSetupProvider);

    return AppScaffold(
      title: 'Staff Account Info',
      body: setupAsync.when(
        data: (setup) {
          _seedControllers(setup);

          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              SectionCard(
                child: Padding(
                  padding: AppSpacing.cardPadding,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Voucher Header', style: AppTextStyles.title),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'These values are stored locally with SharedPreferences and used directly in voucher preview and printing.',
                          style: AppTextStyles.bodyMuted,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextFormField(
                          controller: _businessNameController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            hintText: 'သိင်္ခသူ',
                          ),
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _businessSubtitleController,
                          decoration: const InputDecoration(
                            labelText: 'Subtitle',
                            hintText: 'ခရီးသည် နှင့် ကုန်စည် ပို့ဆောင်ရေး',
                          ),
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _businessAddressController,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            hintText: 'ပါဆပ်ကားလေးကွင်း၊တာချီလိတ်မြို့။',
                          ),
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _businessPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Numbers',
                            hintText: '09250787547,09253003004',
                          ),
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Text(
                          'Header Text Sizes',
                          style: AppTextStyles.label,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _titleSizeController,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Title Size',
                                ),
                                validator: _fontSizeValidator,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: TextFormField(
                                controller: _subtitleSizeController,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Subtitle Size',
                                ),
                                validator: _fontSizeValidator,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneSizeController,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Phone Size',
                                ),
                                validator: _fontSizeValidator,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _InfoRow(label: 'City Code', value: setup.cityCode),
                        const Divider(),
                        _InfoRow(label: 'Account Code', value: setup.accountCode),
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: setupAsync.isLoading ? null : () => _save(setup),
                            child: const Text('Save Changes'),
                          ),
                        ),
                      ],
                    ),
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

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Required.';
    }
    return null;
  }

  String? _fontSizeValidator(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return 'Required.';
    }

    final parsed = double.tryParse(raw);
    if (parsed == null) {
      return 'Invalid.';
    }

    if (parsed < 10 || parsed > 80) {
      return '10-80';
    }

    return null;
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
