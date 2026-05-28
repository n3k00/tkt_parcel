import 'bootstrap.dart';
import 'core/config/app_config.dart';
import 'core/config/app_environment.dart';

Future<void> main() async {
  const config = AppConfig(
    environment: AppEnvironment.prod,
    appName: 'TKT Parcel',
    showDebugBanner: false,
  );
  await bootstrap(config);
}
