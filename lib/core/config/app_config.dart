import 'app_environment.dart';

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.appName,
    required this.showDebugBanner,
    this.supabaseUrl = _defaultSupabaseUrl,
    this.supabaseAnonKey = _defaultSupabaseAnonKey,
  });

  static const _defaultSupabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bcfxcbkezjopwlgsaszb.supabase.co',
  );
  static const _defaultSupabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJjZnhjYmtlempvcHdsZ3Nhc3piIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk0OTU4MTEsImV4cCI6MjA5NTA3MTgxMX0.WlFGWbj7K2Ak8hhdFfceT8rA8eJzoh7EhStLR0gCP_g',
  );

  final AppEnvironment environment;
  final String appName;
  final bool showDebugBanner;
  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get isDev => environment == AppEnvironment.dev;

  bool get isProd => environment == AppEnvironment.prod;

  bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static AppConfig fromEnvironment() {
    final environment = AppEnvironment.fromValue(
      const String.fromEnvironment('APP_ENV', defaultValue: 'prod'),
    );
    final appName = const String.fromEnvironment(
      'APP_NAME',
      defaultValue: 'TKT Parcel',
    );

    return AppConfig(
      environment: environment,
      appName: appName,
      showDebugBanner: environment == AppEnvironment.dev,
    );
  }
}
