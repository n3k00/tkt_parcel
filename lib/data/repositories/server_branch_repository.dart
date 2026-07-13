import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/preferences/app_preferences.dart';
import '../models/town.dart';

class ServerBranchRepository {
  const ServerBranchRepository(this._client, this._preferences);

  final SupabaseClient _client;
  final AppPreferences _preferences;

  Future<List<TownModel>> getSourceTowns() async {
    try {
      final towns = await _fetchSourceTowns();
      if (towns.isNotEmpty) {
        await _preferences.setCachedSourceBranches(
          towns.map((town) => town.toMap()).toList(),
        );
      }
      return towns;
    } catch (_) {
      final cachedTowns = _readCachedSourceBranches();
      if (cachedTowns.isNotEmpty) {
        return cachedTowns;
      }
      rethrow;
    }
  }

  Future<List<TownModel>> _fetchSourceTowns() async {
    if (_client.auth.currentSession == null) {
      throw StateError('Please sign in before refreshing branches.');
    }

    final response = await _client
        .from('branches')
        .select('town_name, city_code')
        .eq('is_active', true)
        .order('city_code', ascending: true);

    return response
        .map(
          (row) => TownModel(
            townName: row['town_name'] as String,
            type: TownType.source,
            cityCode: row['city_code'] as String,
          ),
        )
        .toList();
  }

  List<TownModel> _readCachedSourceBranches() {
    return _preferences
        .getCachedSourceBranches()
        .map(TownModel.fromMap)
        .where((town) => town.isSource)
        .toList()
      ..sort((a, b) => (a.cityCode ?? '').compareTo(b.cityCode ?? ''));
  }
}
