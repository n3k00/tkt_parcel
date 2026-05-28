import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/preferences/app_preferences.dart';
import '../models/town.dart';

class ServerTownRepository {
  const ServerTownRepository(this._client, this._preferences);

  final SupabaseClient _client;
  final AppPreferences _preferences;

  Future<List<TownModel>> getDestinationTowns() async {
    try {
      final towns = await _fetchDestinationTowns();
      if (towns.isNotEmpty) {
        await _preferences.setCachedDestinationTowns(
          towns.map((town) => town.toMap()).toList(),
        );
      }
      return towns;
    } catch (_) {
      final cachedTowns = _readCachedDestinationTowns();
      if (cachedTowns.isNotEmpty) {
        return cachedTowns;
      }
      rethrow;
    }
  }

  Future<List<TownModel>> _fetchDestinationTowns() async {
    if (_client.auth.currentSession == null) {
      throw StateError('Please sign in before refreshing towns.');
    }

    final response = await _client
        .from('towns')
        .select('name_mm, sort_order')
        .eq('active', true)
        .order('sort_order', ascending: true);

    return response
        .map(
          (row) => TownModel(
            townName: row['name_mm'] as String,
            type: TownType.destination,
            sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  List<TownModel> _readCachedDestinationTowns() {
    return _preferences
        .getCachedDestinationTowns()
        .map(TownModel.fromMap)
        .where((town) => town.isDestination)
        .toList()
      ..sort((a, b) {
        final orderCompare = a.sortOrder.compareTo(b.sortOrder);
        if (orderCompare != 0) {
          return orderCompare;
        }
        return a.townName.compareTo(b.townName);
      });
  }
}
