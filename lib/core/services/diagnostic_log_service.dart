import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum DiagnosticCategory { printer, supabase, sync }

class DiagnosticEntry {
  const DiagnosticEntry({
    required this.timestamp,
    required this.category,
    required this.operation,
    required this.userMessage,
    required this.technicalDetails,
  });

  final DateTime timestamp;
  final DiagnosticCategory category;
  final String operation;
  final String userMessage;
  final String technicalDetails;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toUtc().toIso8601String(),
    'category': category.name,
    'operation': operation,
    'user_message': userMessage,
    'technical_details': technicalDetails,
  };

  factory DiagnosticEntry.fromJson(Map<String, dynamic> json) {
    return DiagnosticEntry(
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      category: DiagnosticCategory.values.firstWhere(
        (value) => value.name == json['category'],
        orElse: () => DiagnosticCategory.sync,
      ),
      operation: json['operation'] as String? ?? 'unknown',
      userMessage: json['user_message'] as String? ?? 'Unknown error',
      technicalDetails: json['technical_details'] as String? ?? '',
    );
  }
}

class AppErrorMessages {
  const AppErrorMessages._();

  static String forError(Object error, DiagnosticCategory category) {
    final text = error.toString().toLowerCase();

    if (error is SocketException ||
        text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network') ||
        text.contains('connection refused') ||
        text.contains('timed out') ||
        text.contains('timeout')) {
      return 'အင်တာနက်ချိတ်ဆက်မှု မကောင်းပါ။ လိုင်းစစ်ပြီး ထပ်စမ်းပါ။';
    }
    if (error is AuthException ||
        text.contains('jwt') ||
        text.contains('not authenticated') ||
        text.contains('please sign in')) {
      return 'အကောင့် session သက်တမ်းကုန်နေပါသည်။ ပြန်လည် Login ဝင်ပါ။';
    }
    if (error is PostgrestException &&
            (error.code == '42501' || error.code == 'PGRST301') ||
        text.contains('permission denied') ||
        text.contains('row-level security')) {
      return 'ဒီလုပ်ဆောင်ချက်အတွက် ခွင့်ပြုချက်မရှိပါ။ Admin ကိုဆက်သွယ်ပါ။';
    }
    if (category == DiagnosticCategory.printer) {
      if (text.contains('bluetooth') &&
          (text.contains('off') || text.contains('disabled'))) {
        return 'Bluetooth ပိတ်ထားပါသည်။ Bluetooth ဖွင့်ပြီး ထပ်စမ်းပါ။';
      }
      if (text.contains('permission')) {
        return 'Printer ရှာရန် Bluetooth / Nearby devices permission ကို Allow လုပ်ပါ။';
      }
      if (text.contains('busy')) {
        return 'Printer အလုပ်လုပ်နေဆဲဖြစ်သည်။ ခဏစောင့်ပြီး ထပ်စမ်းပါ။';
      }
      if (text.contains('not connected') || text.contains('connect_failed')) {
        return 'Printer မချိတ်ဆက်ရသေးပါ။ Printer ကိုပြန်ချိတ်ပြီး ထပ်စမ်းပါ။';
      }
      return 'Print မအောင်မြင်ပါ။ Printer ချိတ်ဆက်မှုနှင့် စာရွက်ကိုစစ်ပြီး ထပ်စမ်းပါ။';
    }
    if (category == DiagnosticCategory.sync) {
      return 'Parcel data ပြန်ယူခြင်း မအောင်မြင်ပါ။ အင်တာနက်စစ်ပြီး Refresh ပြန်လုပ်ပါ။';
    }
    return 'Server နှင့်လုပ်ဆောင်မှု မအောင်မြင်ပါ။ လိုင်းစစ်ပြီး ထပ်စမ်းပါ။';
  }
}

class DiagnosticLogService {
  DiagnosticLogService({
    Future<Directory> Function()? directoryProvider,
    this.maxEntries = 200,
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;
  final int maxEntries;
  Future<void> _pendingWrite = Future.value();

  Future<T> capture<T>({
    required DiagnosticCategory category,
    required String operation,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      await recordError(
        category: category,
        operation: operation,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> recordError({
    required DiagnosticCategory category,
    required String operation,
    required Object error,
    StackTrace? stackTrace,
  }) {
    final entry = DiagnosticEntry(
      timestamp: DateTime.now(),
      category: category,
      operation: operation,
      userMessage: AppErrorMessages.forError(error, category),
      technicalDetails: _redact(
        '${error.runtimeType}: $error'
        '${stackTrace == null ? '' : '\n${_shortStack(stackTrace)}'}',
      ),
    );
    _pendingWrite = _pendingWrite.then((_) => _append(entry));
    return _pendingWrite;
  }

  Future<List<DiagnosticEntry>> readEntries() async {
    await _pendingWrite;
    final file = await _logFile();
    if (!await file.exists()) {
      return const [];
    }
    final lines = await file.readAsLines();
    final entries = <DiagnosticEntry>[];
    for (final line in lines) {
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          entries.add(DiagnosticEntry.fromJson(decoded));
        }
      } on FormatException {
        // Ignore a partial/corrupt final line and keep readable diagnostics.
      }
    }
    return entries.reversed.toList(growable: false);
  }

  Future<void> clear() async {
    await _pendingWrite;
    final file = await _logFile();
    if (await file.exists()) {
      await file.writeAsString('', flush: true);
    }
  }

  Future<void> _append(DiagnosticEntry entry) async {
    final file = await _logFile();
    final existing = await file.exists()
        ? await file.readAsLines()
        : <String>[];
    final next = <String>[...existing, jsonEncode(entry.toJson())];
    final retained = next.length > maxEntries
        ? next.sublist(next.length - maxEntries)
        : next;
    await file.writeAsString('${retained.join('\n')}\n', flush: true);
  }

  Future<File> _logFile() async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    return File(
      '${directory.path}${Platform.pathSeparator}diagnostic_logs.jsonl',
    );
  }

  static String _shortStack(StackTrace stackTrace) {
    return stackTrace.toString().split('\n').take(8).join('\n');
  }

  static String _redact(String value) {
    return value
        .replaceAll(
          RegExp(r'sb_(publishable|secret)_[A-Za-z0-9_-]+'),
          '[REDACTED_KEY]',
        )
        .replaceAll(
          RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
          '[REDACTED_TOKEN]',
        );
  }
}
