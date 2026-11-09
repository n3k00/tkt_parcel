import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/diagnostic_log_service.dart';

final diagnosticLogServiceProvider = Provider<DiagnosticLogService>((ref) {
  return DiagnosticLogService();
});

final diagnosticEntriesProvider = FutureProvider<List<DiagnosticEntry>>((ref) {
  return ref.watch(diagnosticLogServiceProvider).readEntries();
});
