import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../parcel/presentation/screens/home_screen.dart';
import '../../providers/auth_provider.dart';
import 'auth_splash_screen.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.config});

  static const routeName = '/';

  final AppConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!config.isSupabaseConfigured) {
      return const LoginScreen(
        configurationError:
            'Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }

    ref.watch(authStateProvider);
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const LoginScreen();
    }

    final profileAsync = ref.watch(staffProfileProvider);
    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const _MissingProfileView();
        }
        return const HomeScreen();
      },
      loading: () => AuthSplashScreen(appName: config.appName),
      error: (error, _) => AppErrorView(message: error.toString()),
    );
  }
}

class _MissingProfileView extends ConsumerWidget {
  const _MissingProfileView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Setup')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.person_off_outlined, size: 44),
            const SizedBox(height: 16),
            const Text(
              'This login does not have an active staff profile.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await ref.read(authRepositoryProvider).signOut();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}
