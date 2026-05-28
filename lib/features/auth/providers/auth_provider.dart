import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/local/preferences/app_preferences.dart';
import '../data/models/staff_profile.dart';
import '../data/repositories/auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

final staffProfileProvider = FutureProvider<StaffProfile?>((ref) async {
  ref.watch(authStateProvider);
  final repository = ref.watch(authRepositoryProvider);
  final currentUser = repository.currentUser;
  if (currentUser == null) {
    return null;
  }

  final preferences = await AppPreferences.create();
  try {
    final profile = await repository.fetchCurrentStaffProfile();
    if (profile != null) {
      await preferences.setCachedStaffProfile(profile.toMap());
    }
    return profile;
  } catch (_) {
    final cached = preferences.getCachedStaffProfile();
    if (cached == null || cached['user_id'] != currentUser.id) {
      rethrow;
    }
    return StaffProfile.fromMap(cached);
  }
});
