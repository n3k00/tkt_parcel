import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../../providers/parcel_repository_provider.dart';
import '../../data/models/staff_profile.dart';
import '../../providers/auth_provider.dart';
import 'auth_gate.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  static const routeName = '/settings/account';

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _isSigningOut = false;
  bool _isSavingBranch = false;
  bool _isRefreshingBranch = false;
  bool _didSeedBranchFields = false;
  DateTime? _lastLoadedFromServerAt;

  final _branchFormKey = GlobalKey<FormState>();
  final _branchAddressController = TextEditingController();
  final _branchPhoneController = TextEditingController();

  @override
  void dispose() {
    _branchAddressController.dispose();
    _branchPhoneController.dispose();
    super.dispose();
  }

  Future<void> _seedBranchFields(
    StaffProfile profile, {
    bool force = false,
  }) async {
    if (_didSeedBranchFields && !force) {
      return;
    }

    final settingsRepository = await ref.read(
      settingsRepositoryProvider.future,
    );
    final localSetup = await settingsRepository.getAppSetup();
    if (!mounted || _didSeedBranchFields) {
      return;
    }

    _branchAddressController.text =
        profile.branchAddress?.trim().isNotEmpty == true
        ? profile.branchAddress!.trim()
        : localSetup.businessAddress;
    _branchPhoneController.text =
        profile.branchPhoneNumbers?.trim().isNotEmpty == true
        ? profile.branchPhoneNumbers!.trim()
        : localSetup.businessPhone;
    _didSeedBranchFields = true;
  }

  void _markProfileLoaded() {
    if (_lastLoadedFromServerAt != null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastLoadedFromServerAt != null) {
        return;
      }
      setState(() {
        _lastLoadedFromServerAt = DateTime.now();
      });
    });
  }

  Future<StaffProfile?> _refreshBranchProfile({
    bool showSuccessMessage = true,
    bool showFailureMessage = true,
  }) async {
    if (_isRefreshingBranch) {
      return null;
    }

    setState(() {
      _isRefreshingBranch = true;
    });

    try {
      _didSeedBranchFields = false;
      final profile = await ref.refresh(staffProfileProvider.future);
      if (!mounted) {
        return profile;
      }

      if (profile != null && !profile.isAdmin) {
        await _seedBranchFields(profile, force: true);
      }
      if (!mounted) {
        return profile;
      }

      setState(() {
        _lastLoadedFromServerAt = DateTime.now();
      });

      if (showSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branch profile refreshed.')),
        );
      }
      return profile;
    } catch (error) {
      if (mounted && showFailureMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Branch profile refresh failed: $error')),
        );
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingBranch = false;
        });
      }
    }
  }

  Future<void> _saveBranchProfile(StaffProfile profile) async {
    if (_isSavingBranch || !_branchFormKey.currentState!.validate()) {
      return;
    }
    final branchId = profile.branchId;
    if (branchId == null || branchId.isEmpty) {
      return;
    }

    setState(() {
      _isSavingBranch = true;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .updateBranchProfile(
            branchId: branchId,
            address: _branchAddressController.text,
            phoneNumbers: _branchPhoneController.text,
          );
      try {
        await _refreshBranchProfile(
          showSuccessMessage: false,
          showFailureMessage: false,
        );
      } catch (error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Branch profile saved, but refresh failed: $error'),
          ),
        );
        return;
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Branch profile saved and refreshed.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Branch profile save failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingBranch = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    if (_isSigningOut) {
      return;
    }

    setState(() {
      _isSigningOut = true;
    });

    try {
      await ref.read(authRepositoryProvider).signOut();
      if (!mounted) {
        return;
      }
      ref.invalidate(currentUserProvider);
      ref.invalidate(staffProfileProvider);
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AuthGate.routeName, (_) => false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign out failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(staffProfileProvider);

    return AppScaffold(
      title: 'Account',
      body: profileAsync.when(
        data: (profile) {
          if (profile != null && !profile.isAdmin) {
            _markProfileLoaded();
            unawaited(_seedBranchFields(profile));
          }

          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              SectionCard(
                child: Padding(
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.email ?? 'Signed in',
                        style: AppTextStyles.title,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        profile == null
                            ? 'No active staff profile'
                            : '${profile.role.toUpperCase()} - ${profile.accessLabel}',
                        style: AppTextStyles.bodyMuted,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (profile != null &&
                          !profile.isAdmin &&
                          profile.branchId != null) ...[
                        const Divider(),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Branch Profile',
                                style: AppTextStyles.subtitle,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refresh branch profile',
                              onPressed: _isSavingBranch || _isRefreshingBranch
                                  ? null
                                  : () => _refreshBranchProfile(),
                              icon: _isRefreshingBranch
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          profile.accessLabel,
                          style: AppTextStyles.bodyMuted,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _branchLoadedLabel(context),
                          style: AppTextStyles.bodyMuted,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Form(
                          key: _branchFormKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _branchAddressController,
                                enabled:
                                    !_isSavingBranch && !_isRefreshingBranch,
                                decoration: const InputDecoration(
                                  labelText: 'Address',
                                  prefixIcon: Icon(Icons.location_on_outlined),
                                ),
                                validator: _requiredValidator,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              TextFormField(
                                controller: _branchPhoneController,
                                enabled:
                                    !_isSavingBranch && !_isRefreshingBranch,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Numbers',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ),
                                validator: _requiredValidator,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed:
                                      _isSavingBranch || _isRefreshingBranch
                                      ? null
                                      : () => _saveBranchProfile(profile),
                                  icon: _isSavingBranch
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: Text(
                                    _isSavingBranch
                                        ? 'Saving...'
                                        : 'Save Branch Profile',
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSigningOut ? null : _signOut,
                          icon: const Icon(Icons.logout_rounded),
                          label: Text(
                            _isSigningOut ? 'Signing Out...' : 'Sign Out',
                          ),
                        ),
                      ),
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

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Required.';
    }
    return null;
  }

  String _branchLoadedLabel(BuildContext context) {
    final lastLoadedAt = _lastLoadedFromServerAt;
    if (lastLoadedAt == null) {
      return 'Last loaded from server: Loading...';
    }

    final localTime = TimeOfDay.fromDateTime(
      lastLoadedAt.toLocal(),
    ).format(context);
    return 'Last loaded from server: $localTime';
  }
}
