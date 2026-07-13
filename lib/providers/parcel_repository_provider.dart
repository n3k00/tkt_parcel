import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/qr_service.dart';
import '../data/local/preferences/app_preferences.dart';
import '../data/repositories/parcel_repository.dart';
import '../data/repositories/server_branch_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/server_town_repository.dart';
import '../data/repositories/sync_repository.dart';
import '../data/repositories/town_repository.dart';
import '../features/auth/providers/auth_provider.dart';
import 'database_provider.dart';

final appPreferencesProvider = FutureProvider<AppPreferences>((ref) async {
  return AppPreferences.create();
});

final settingsRepositoryProvider = FutureProvider<SettingsRepository>((
  ref,
) async {
  final preferences = await ref.watch(appPreferencesProvider.future);
  return SettingsRepository(preferences);
});

final parcelRepositoryProvider = Provider<ParcelRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return ParcelRepository(database.parcelsDao);
});

final townRepositoryProvider = Provider<TownRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return TownRepository(database.townsDao);
});

final serverTownRepositoryProvider = FutureProvider<ServerTownRepository>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final preferences = await ref.watch(appPreferencesProvider.future);
  return ServerTownRepository(client, preferences);
});

final serverBranchRepositoryProvider = FutureProvider<ServerBranchRepository>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final preferences = await ref.watch(appPreferencesProvider.future);
  return ServerBranchRepository(client, preferences);
});

final qrServiceProvider = Provider<QrService>((ref) {
  return QrService();
});
final syncRepositoryProvider = FutureProvider<SyncRepository>((ref) async {
  final preferences = await ref.watch(appPreferencesProvider.future);
  return SyncRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(parcelRepositoryProvider),
    preferences,
  );
});
