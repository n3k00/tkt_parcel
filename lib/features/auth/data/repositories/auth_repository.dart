import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/staff_profile.dart';

class AuthRepository {
  const AuthRepository(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.session == null || response.user == null) {
      throw const AuthException('Sign in failed. Please try again.');
    }
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  Future<StaffProfile?> fetchCurrentStaffProfile() async {
    final user = currentUser;
    if (user == null) {
      return null;
    }

    final row = await _client
        .from('staff_profiles')
        .select(
          'user_id, branch_id, role, is_active, branches(city_code, town_name, branch_type, address, phone_numbers)',
        )
        .eq('user_id', user.id)
        .eq('is_active', true)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return StaffProfile.fromMap(row);
  }

  Future<BranchProfile?> fetchBranchProfile(String branchId) async {
    final row = await _client
        .from('branches')
        .select('id, town_name, city_code, address, phone_numbers')
        .eq('id', branchId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return BranchProfile.fromMap(row);
  }

  Future<void> updateBranchProfile({
    required String branchId,
    required String address,
    required String phoneNumbers,
  }) async {
    final row = await _client
        .from('branches')
        .update({
          'address': address.trim(),
          'phone_numbers': phoneNumbers.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', branchId)
        .select('id')
        .maybeSingle();

    if (row == null) {
      throw const AuthException('Branch profile update was not allowed.');
    }
  }
}
