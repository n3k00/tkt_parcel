import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class BackupResult {
  const BackupResult({required this.path, required this.message});

  final String path;
  final String message;
}

class RestoreResult {
  const RestoreResult({required this.message, required this.usedBackupPath});

  final String message;
  final String usedBackupPath;
}

class BackupRestoreService {
  const BackupRestoreService();

  static const _databaseFileName = 'tkt_parcel.sqlite';
  static const _imageDirectoryName = 'parcel_images';
  static const _backupFolderName = 'TKT Parcel Backups';
  static const _currentSchemaVersion = 3;

  Future<BackupResult> createFullBackup() async {
    final databaseFile = await _databaseFile();
    final outputDirectory = await _backupOutputDirectory();
    await outputDirectory.create(recursive: true);

    final archive = Archive();
    archive.addFile(
      ArchiveFile(
        _databaseFileName,
        databaseFile.lengthSync(),
        await databaseFile.readAsBytes(),
      ),
    );

    final imageDirectory = await _parcelImageDirectory();
    if (await imageDirectory.exists()) {
      await for (final entity in imageDirectory.list(recursive: true)) {
        if (entity is! File) {
          continue;
        }
        final relativePath = path.relative(
          entity.path,
          from: imageDirectory.path,
        );
        archive.addFile(
          ArchiveFile(
            path.join(_imageDirectoryName, relativePath),
            entity.lengthSync(),
            await entity.readAsBytes(),
          ),
        );
      }
    }

    final timestamp = _timestamp();
    final outputPath = path.join(
      outputDirectory.path,
      'tkt_parcel_full_$timestamp.zip',
    );
    final outputStream = OutputFileStream(outputPath);
    ZipEncoder().encodeStream(archive, outputStream);
    outputStream.close();

    return BackupResult(
      path: outputPath,
      message: 'Full backup created successfully.',
    );
  }

  Future<BackupResult> createLightBackup() async {
    final databaseFile = await _databaseFile();
    final outputDirectory = await _backupOutputDirectory();
    await outputDirectory.create(recursive: true);

    final timestamp = _timestamp();
    final outputPath = path.join(
      outputDirectory.path,
      'tkt_parcel_light_$timestamp.sqlite',
    );
    await databaseFile.copy(outputPath);

    return BackupResult(
      path: outputPath,
      message: 'Light backup created successfully.',
    );
  }

  Future<RestoreResult> restoreBackup(String backupPath) async {
    final sourceFile = File(backupPath);
    if (!await sourceFile.exists()) {
      throw StateError('Selected backup file could not be found.');
    }

    final extension = path.extension(sourceFile.path).toLowerCase();
    if (extension == '.zip') {
      return _restoreFromZip(sourceFile);
    }
    if (extension == '.sqlite' || extension == '.db') {
      _validateBackupDatabase(sourceFile);
      await _replaceDatabaseFile(sourceFile);
      return RestoreResult(
        message: 'Database restored successfully.',
        usedBackupPath: sourceFile.path,
      );
    }

    throw StateError('Unsupported backup format.');
  }

  Future<RestoreResult> _restoreFromZip(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final databaseEntry = archive.findFile(_databaseFileName);
    if (databaseEntry == null) {
      throw StateError('The selected backup is missing the database file.');
    }

    final tempDirectory = await getTemporaryDirectory();
    final workingDirectory = Directory(
      path.join(
        tempDirectory.path,
        'backup_restore_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await workingDirectory.create(recursive: true);

    try {
      final extractedDatabase = File(
        path.join(workingDirectory.path, _databaseFileName),
      );
      await extractedDatabase.writeAsBytes(
        _archiveBytes(databaseEntry),
        flush: true,
      );
      _validateBackupDatabase(extractedDatabase);
      await _replaceDatabaseFile(extractedDatabase);

      final imageEntries = archive.files
          .where(
            (file) =>
                !file.isDirectory &&
                file.name.startsWith('$_imageDirectoryName/'),
          )
          .toList();
      if (imageEntries.isNotEmpty) {
        final targetImageDirectory = await _parcelImageDirectory();
        if (await targetImageDirectory.exists()) {
          await targetImageDirectory.delete(recursive: true);
        }
        await targetImageDirectory.create(recursive: true);

        for (final imageEntry in imageEntries) {
          final relativePath = imageEntry.name.substring(
            _imageDirectoryName.length + 1,
          );
          final outputFile = File(
            path.join(targetImageDirectory.path, relativePath),
          );
          await outputFile.parent.create(recursive: true);
          await outputFile.writeAsBytes(_archiveBytes(imageEntry), flush: true);
        }
      }

      return RestoreResult(
        message: 'Backup restored successfully.',
        usedBackupPath: zipFile.path,
      );
    } finally {
      if (await workingDirectory.exists()) {
        await workingDirectory.delete(recursive: true);
      }
    }
  }

  Future<void> _replaceDatabaseFile(File sourceDatabase) async {
    final targetDatabase = await _databaseFile();
    await targetDatabase.parent.create(recursive: true);

    final tempPath = '${targetDatabase.path}.restore';
    final tempFile = await sourceDatabase.copy(tempPath);
    if (await targetDatabase.exists()) {
      await targetDatabase.delete();
    }
    await tempFile.rename(targetDatabase.path);
  }

  void _validateBackupDatabase(File databaseFile) {
    Database? database;
    try {
      database = sqlite3.open(databaseFile.path, mode: OpenMode.readOnly);
      final schemaVersion =
          database.select('PRAGMA user_version').first.values.first as int;
      if (schemaVersion < 1 || schemaVersion > _currentSchemaVersion) {
        throw StateError(
          'Unsupported backup database version: $schemaVersion.',
        );
      }

      final existingTables = database
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('parcels', 'towns')",
          )
          .map((row) => row['name'] as String)
          .toSet();
      final missingTables = <String>[
        if (!existingTables.contains('parcels')) 'parcels',
        if (!existingTables.contains('towns')) 'towns',
      ];
      if (missingTables.isNotEmpty) {
        throw StateError(
          'Invalid backup database. Missing table(s): ${missingTables.join(', ')}.',
        );
      }
    } on SqliteException catch (error) {
      throw StateError('Invalid backup database file: ${error.message}');
    } finally {
      database?.close();
    }
  }

  Future<File> _databaseFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File(path.join(directory.path, _databaseFileName));
  }

  Future<Directory> _parcelImageDirectory() async {
    final baseDirectory = await getApplicationSupportDirectory();
    return Directory(path.join(baseDirectory.path, _imageDirectoryName));
  }

  Future<Directory> _backupOutputDirectory() async {
    if (Platform.isAndroid) {
      final downloadsDirectory = Directory('/storage/emulated/0/Download');
      if (await downloadsDirectory.exists()) {
        return Directory(path.join(downloadsDirectory.path, _backupFolderName));
      }
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    return Directory(path.join(documentsDirectory.path, _backupFolderName));
  }

  Uint8List _archiveBytes(ArchiveFile file) {
    return file.readBytes() ?? Uint8List(0);
  }

  String _timestamp() {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return '$year$month${day}_$hour$minute$second';
  }
}
