import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_info_service.dart';
import '../../../../providers/parcel_repository_provider.dart';
import '../../../../shared/models/app_setup_config.dart';

class SettingsViewData {
  const SettingsViewData({required this.setup, required this.appInfo});

  final AppSetupConfig setup;
  final AppVersionInfo appInfo;
}

class SettingsSetupNotifier extends AsyncNotifier<AppSetupConfig> {
  @override
  Future<AppSetupConfig> build() async {
    final repository = await ref.read(settingsRepositoryProvider.future);
    return repository.getAppSetup();
  }

  Future<void> saveSetup(AppSetupConfig config) async {
    state = const AsyncLoading();
    final repository = await ref.read(settingsRepositoryProvider.future);
    await repository.saveAppSetup(config);
    state = AsyncData(await repository.getAppSetup());
  }
}

final appInfoServiceProvider = Provider<AppInfoService>((ref) {
  return const AppInfoService();
});

final appVersionInfoProvider = FutureProvider<AppVersionInfo>((ref) async {
  final service = ref.watch(appInfoServiceProvider);
  return service.getAppVersionInfo();
});

final settingsSetupProvider =
    AsyncNotifierProvider<SettingsSetupNotifier, AppSetupConfig>(
      SettingsSetupNotifier.new,
    );

final settingsDataProvider = FutureProvider<SettingsViewData>((ref) async {
  final setup = await ref.watch(settingsSetupProvider.future);
  final appInfo = await ref.watch(appVersionInfoProvider.future);

  return SettingsViewData(setup: setup, appInfo: appInfo);
});
