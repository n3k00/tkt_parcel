import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_info_service.dart';
import '../../../../providers/parcel_repository_provider.dart';
import '../../../../shared/models/app_setup_config.dart';

class SettingsViewData {
  const SettingsViewData({required this.setup, required this.appInfo});

  final AppSetupConfig setup;
  final AppVersionInfo appInfo;
}

final appInfoServiceProvider = Provider<AppInfoService>((ref) {
  return const AppInfoService();
});

final appVersionInfoProvider = FutureProvider<AppVersionInfo>((ref) async {
  final service = ref.watch(appInfoServiceProvider);
  return service.getAppVersionInfo();
});

final settingsDataProvider = FutureProvider<SettingsViewData>((ref) async {
  final settingsRepository = await ref.watch(settingsRepositoryProvider.future);
  final setup = await settingsRepository.getAppSetup();
  final appInfo = await ref.watch(appVersionInfoProvider.future);

  return SettingsViewData(setup: setup, appInfo: appInfo);
});
