import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/layout/app_responsive.dart';
import '../../../../core/services/diagnostic_log_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../providers/diagnostic_provider.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_scaffold.dart';

class DiagnosticLogsScreen extends ConsumerStatefulWidget {
  const DiagnosticLogsScreen({super.key});

  static const routeName = '/settings/diagnostic-logs';

  @override
  ConsumerState<DiagnosticLogsScreen> createState() =>
      _DiagnosticLogsScreenState();
}

class _DiagnosticLogsScreenState extends ConsumerState<DiagnosticLogsScreen> {
  DiagnosticCategory? _category;

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(diagnosticEntriesProvider);

    return AppScaffold(
      title: 'Diagnostic Logs',
      actions: [
        IconButton(
          tooltip: 'Copy logs',
          onPressed: entriesAsync.asData?.value.isNotEmpty == true
              ? () => _copyLogs(entriesAsync.requireValue)
              : null,
          icon: const Icon(Icons.copy_all_outlined),
        ),
        IconButton(
          tooltip: 'Clear logs',
          onPressed: entriesAsync.asData?.value.isNotEmpty == true
              ? _clearLogs
              : null,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
      body: entriesAsync.when(
        loading: AppLoading.new,
        error: (error, _) => const AppErrorView(
          message: 'Diagnostic logs ဖတ်မရပါ။ App ကိုပြန်ဖွင့်ပြီး စမ်းပါ။',
        ),
        data: (entries) {
          final visible = _category == null
              ? entries
              : entries
                    .where((entry) => entry.category == _category)
                    .toList(growable: false);
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: AppResponsive.centeredContentWidth(
                context,
                horizontalPadding: AppSpacing.md,
              ),
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        _filterChip(label: 'All', category: null),
                        const SizedBox(width: AppSpacing.sm),
                        _filterChip(
                          label: 'Printer',
                          category: DiagnosticCategory.printer,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _filterChip(
                          label: 'Supabase',
                          category: DiagnosticCategory.supabase,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _filterChip(
                          label: 'Sync',
                          category: DiagnosticCategory.sync,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: visible.isEmpty
                        ? const Center(
                            child: Text('မှတ်တမ်းတင်ထားသော error မရှိသေးပါ။'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.sm,
                              AppSpacing.md,
                              AppSpacing.xl,
                            ),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (_, index) =>
                                _DiagnosticEntryCard(entry: visible[index]),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required DiagnosticCategory? category,
  }) {
    return FilterChip(
      label: Text(label),
      selected: _category == category,
      onSelected: (_) => setState(() => _category = category),
    );
  }

  Future<void> _copyLogs(List<DiagnosticEntry> entries) async {
    final visible = _category == null
        ? entries
        : entries.where((entry) => entry.category == _category).toList();
    final text = visible.map(_entryText).join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Diagnostic logs copied.')));
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear diagnostic logs?'),
        content: const Text(
          'သိမ်းထားသော local error logs အားလုံးကိုရှင်းပါမည်။',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(diagnosticLogServiceProvider).clear();
    ref.invalidate(diagnosticEntriesProvider);
  }

  String _entryText(DiagnosticEntry entry) {
    return '[${entry.timestamp.toIso8601String()}] '
        '[${entry.category.name.toUpperCase()}] ${entry.operation}\n'
        '${entry.userMessage}\n${entry.technicalDetails}';
  }
}

class _DiagnosticEntryCard extends StatelessWidget {
  const _DiagnosticEntryCard({required this.entry});

  final DiagnosticEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${entry.category.name.toUpperCase()} · ${entry.operation}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  _formatTime(entry.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(entry.userMessage),
            const SizedBox(height: AppSpacing.xs),
            SelectableText(
              entry.technicalDetails,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (entry.category) {
    DiagnosticCategory.printer => Icons.print_outlined,
    DiagnosticCategory.supabase => Icons.cloud_outlined,
    DiagnosticCategory.sync => Icons.sync_problem_outlined,
  };

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
