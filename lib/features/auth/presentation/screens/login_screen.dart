import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../providers/auth_provider.dart';
import 'auth_gate.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.configurationError});

  static const routeName = '/login';

  final String? configurationError;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSigningIn = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate() || _isSigningIn) {
      return;
    }

    setState(() {
      _isSigningIn = true;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted) {
        return;
      }
      ref.invalidate(currentUserProvider);
      ref.invalidate(staffProfileProvider);
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AuthGate.routeName, (_) => false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configError = widget.configurationError;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return Center(
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 760 : 440),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(child: _LoginBrandPanel()),
                            const SizedBox(width: AppSpacing.xl),
                            Expanded(
                              child: _LoginFormCard(
                                form: _buildForm(configError),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _LoginBrandPanel(compact: true),
                            const SizedBox(height: AppSpacing.lg),
                            _LoginFormCard(form: _buildForm(configError)),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm(String? configError) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Staff Login', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Use your branch account to create and sync official parcels.',
            style: AppTextStyles.bodyMuted,
          ),
          if (configError != null) ...[
            const SizedBox(height: AppSpacing.md),
            _InlineError(message: configError),
          ],
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _emailController,
            enabled: !_isSigningIn && configError == null,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: _requiredValidator,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _passwordController,
            enabled: !_isSigningIn && configError == null,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: _requiredValidator,
            onFieldSubmitted: (_) => _signIn(),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _isSigningIn || configError != null ? null : _signIn,
              icon: _isSigningIn
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(_isSigningIn ? 'Signing In' : 'Sign In'),
            ),
          ),
        ],
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Required.';
    }
    return null;
  }

  String _friendlyError(Object error) {
    if (error is AuthException) {
      return error.message;
    }
    return 'Sign in failed. Please check the account and password.';
  }
}

class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 56 : 72,
          height: compact ? 56 : 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.local_shipping_outlined,
            color: Theme.of(context).colorScheme.onPrimary,
            size: compact ? 30 : 38,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'TKT Parcel',
          style: compact ? AppTextStyles.title : AppTextStyles.display,
          textAlign: compact ? TextAlign.center : TextAlign.start,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Counter operations',
          style: AppTextStyles.bodyMuted,
          textAlign: compact ? TextAlign.center : TextAlign.start,
        ),
      ],
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Padding(padding: AppSpacing.cardPadding, child: form),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMuted.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
