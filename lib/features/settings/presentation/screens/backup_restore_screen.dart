import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/backup_restore_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../providers/database_provider.dart';
import '../../../../providers/parcel_repository_provider.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../parcel/presentation/providers/parcel_list_provider.dart';
import '../providers/settings_provider.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  static const routeName = '/settings/backup-restore';

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _isProcessing = false;
  String _statusText = 'Select a backup tool.';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.backupRestoreTitle,
      isBlocking: _isProcessing,
      blockingOverlay: ColoredBox(
        color: Colors.black26,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(
                _statusText,
                style: AppTextStyles.body.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          _ActionTile(
            icon: Icons.archive_outlined,
            title: AppStrings.fullBackupTitle,
            subtitle: AppStrings.fullBackupSubtitle,
            onTap: _handleFullBackup,
          ),
          const Divider(height: 1),
          _ActionTile(
            icon: Icons.save_outlined,
            title: AppStrings.lightBackupTitle,
            subtitle: AppStrings.lightBackupSubtitle,
            onTap: _handleLightBackup,
          ),
          const Divider(height: 1),
          _ActionTile(
            icon: Icons.restore_page_outlined,
            title: AppStrings.restoreBackupTitle,
            subtitle: AppStrings.restoreBackupSubtitle,
            onTap: _handleRestore,
          ),
        ],
      ),
    );
  }

  Future<void> _handleFullBackup() async {
    final permissionResult = await _ensureBackupPermission();
    if (!permissionResult) {
      return;
    }

    await _runBackupOperation(
      progressText: 'Creating full backup...',
      action: (service) async {
        final result = await service.createFullBackup();
        return '${result.message}\n${result.path}';
      },
    );
  }

  Future<void> _handleLightBackup() async {
    final permissionResult = await _ensureBackupPermission();
    if (!permissionResult) {
      return;
    }

    await _runBackupOperation(
      progressText: 'Creating light backup...',
      action: (service) async {
        final result = await service.createLightBackup();
        return '${result.message}\n${result.path}';
      },
    );
  }

  Future<void> _handleRestore() async {
    final permissionResult = await _ensureBackupPermission();
    if (!permissionResult) {
      return;
    }

    final service = ref.read(backupRestoreServiceProvider);
    final backupFiles = await service.listAvailableRestoreFiles();
    if (backupFiles.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.noBackupFilesFound)),
      );
      return;
    }

    final selectedFile = await _showRestoreFilePicker(backupFiles);
    if (selectedFile == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final shouldRestore =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text(AppStrings.restoreBackupTitle),
            content: Text(
              'Restore from:\n${selectedFile.path}\n\nThis will replace the current local parcel database.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text(AppStrings.cancelAction),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(AppStrings.restoreBackupTitle),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldRestore) {
      return;
    }
    if (!mounted) {
      return;
    }

    await _runOperation(
      progressText: 'Restoring backup...',
      action: () async {
        final database = ref.read(databaseProvider);
        await database.close();

        final result = await service.restoreBackup(selectedFile.path);

        ref.invalidate(databaseProvider);
        ref.invalidate(parcelRepositoryProvider);
        ref.invalidate(townRepositoryProvider);
        ref.invalidate(parcelListProvider);

        return '${result.message}\n${result.usedBackupPath}';
      },
    );
  }

  Future<BackupFileEntry?> _showRestoreFilePicker(
    List<BackupFileEntry> files,
  ) async {
    return showModalBottomSheet<BackupFileEntry>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.chooseBackupFileTitle,
                    style: AppTextStyles.title,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.chooseBackupFileSubtitle,
                    style: AppTextStyles.bodyMuted,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: files.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final file = files[index];
                  return ListTile(
                    title: Text(file.name, style: AppTextStyles.label),
                    subtitle: Text(
                      '${_formatBytes(file.sizeBytes)} • ${_formatDateTime(file.modifiedAt)}',
                      style: AppTextStyles.bodyMuted,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(sheetContext).pop(file),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  Future<bool> _ensureBackupPermission() async {
    final permissionResult = await ref
        .read(storagePermissionServiceProvider)
        .ensureBackupPermissions();
    if (permissionResult.isGranted) {
      return true;
    }

    if (permissionResult.requiresSettings) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            permissionResult.message ?? AppStrings.backupPermissionBlocked,
          ),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
      return false;
    }

    if (!mounted) {
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          permissionResult.message ?? AppStrings.backupPermissionBlocked,
        ),
      ),
    );
    return false;
  }

  Future<void> _runBackupOperation({
    required String progressText,
    required Future<String> Function(BackupRestoreService service) action,
  }) async {
    await _runOperation(
      progressText: progressText,
      action: () async {
        final service = ref.read(backupRestoreServiceProvider);
        final database = ref.read(databaseProvider);
        await database.close();

        try {
          return await action(service);
        } finally {
          ref.invalidate(databaseProvider);
          ref.invalidate(parcelRepositoryProvider);
          ref.invalidate(townRepositoryProvider);
          ref.invalidate(parcelListProvider);
        }
      },
    );
  }

  Future<void> _runOperation({
    required String progressText,
    required Future<String> Function() action,
  }) async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusText = progressText;
    });

    try {
      final message = await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusText = 'Select a backup tool.';
        });
      }
    }
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      minLeadingWidth: 28,
      horizontalTitleGap: AppSpacing.sm,
      leading: Icon(icon),
      title: Text(title, style: AppTextStyles.label),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle, style: AppTextStyles.bodyMuted),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
