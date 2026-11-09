import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tkt_parcel/core/services/diagnostic_log_service.dart';

void main() {
  late Directory directory;
  late DiagnosticLogService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tkt_diagnostics_');
    service = DiagnosticLogService(
      directoryProvider: () async => directory,
      maxEntries: 2,
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('stores categorized errors and keeps newest entries', () async {
    for (var index = 1; index <= 3; index++) {
      await service.recordError(
        category: DiagnosticCategory.sync,
        operation: 'pull_$index',
        error: StateError('failure $index'),
      );
    }

    final entries = await service.readEntries();

    expect(entries, hasLength(2));
    expect(entries.first.operation, 'pull_3');
    expect(entries.last.operation, 'pull_2');
  });

  test('redacts client keys and JWT-like tokens', () async {
    await service.recordError(
      category: DiagnosticCategory.supabase,
      operation: 'create_parcel',
      error: StateError(
        'sb_publishable_exampleSecret123 '
        'eyJheader123456789.payload123456789.signature123456789',
      ),
    );

    final entry = (await service.readEntries()).single;

    expect(entry.technicalDetails, contains('[REDACTED_KEY]'));
    expect(entry.technicalDetails, contains('[REDACTED_TOKEN]'));
    expect(entry.technicalDetails, isNot(contains('exampleSecret123')));
  });

  test('returns a user-friendly printer message', () {
    final message = AppErrorMessages.forError(
      StateError('connect_failed'),
      DiagnosticCategory.printer,
    );

    expect(message, contains('Printer'));
    expect(message, isNot(contains('connect_failed')));
  });

  test('clear removes all entries', () async {
    await service.recordError(
      category: DiagnosticCategory.printer,
      operation: 'print_label',
      error: StateError('failed'),
    );

    await service.clear();

    expect(await service.readEntries(), isEmpty);
  });
}
