import 'dart:async';
import 'dart:io' as io;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/backup_file_name.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';

typedef DAVClientFactory = DAVClient Function(DAVProps props);

abstract final class DAVDirectory {
  static final _invalid = RegExp(r'[\\<>:"|?*\x00-\x1f]');

  static String normalize(String value) {
    final segments = value.trim().split('/').where((part) => part.isNotEmpty);
    return '/${segments.join('/')}';
  }

  static bool isValid(String value) =>
      !_invalid.hasMatch(value) &&
      !value.trim().split('/').any((part) => part == '.' || part == '..');
}

class DAVClient {
  late DAVTransport client;
  late String fileName;
  final String directory;

  DAVClient(DAVProps dav) : directory = DAVDirectory.normalize(dav.directory) {
    client = DAVTransport(uri: dav.uri, user: dav.user, password: dav.password);
    fileName = dav.fileName;
  }

  Future<bool> ping() async {
    try {
      await client.options('/');
      return true;
    } catch (e) {
      commonPrint.log(
        'dav ping error ${e.toString()}',
        logLevel: LogLevel.warning,
      );
      return false;
    }
  }

  String get root => directory;

  Future<bool> backup(String localFilePath, {required String name}) async {
    if (!DAVDirectory.isValid(directory)) {
      throw MessageException(currentAppLocalizations.invalidDavDirectory);
    }
    var path = '';
    for (final segment
        in directory.split('/').where((part) => part.isNotEmpty)) {
      path = '$path/$segment';
      await client.mkcol(path);
    }
    await client.put('$root/$name', await io.File(localFilePath).readAsBytes());
    return true;
  }

  Future<List<DAVFile>> listBackups() async {
    try {
      final files = await client.list(root);
      return files
          .where(
            (file) =>
                file.name.toLowerCase().endsWith('.zip') ||
                file.name == fileName,
          )
          .toList();
    } on DAVException catch (error) {
      if ((error.statusCode == 405 || error.statusCode == 501) &&
          !BackupFileName.hasVariables(fileName)) {
        return [DAVFile(name: fileName)];
      }
      rethrow;
    }
  }

  Future<List<String>> listDirectories(String path) async {
    final directories = await client.list(
      DAVDirectory.normalize(path),
      directoriesOnly: true,
    );
    return directories
        .map((directory) => directory.name)
        .where(DAVDirectory.isValid)
        .toList();
  }

  Future<void> deleteBackup(String name) async {
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.contains('/') ||
        name.contains('\\')) {
      throw ArgumentError.value(name, 'name', 'Expected a backup file name');
    }
    await client.delete('$root/$name');
  }

  Future<void> restore({required String name}) async {
    final backupFilePath = await appPath.backupFilePath;
    final bytes = await client.get('$root/$name');
    await io.File(backupFilePath).safeWriteAsBytes(bytes);
  }
}

class DAVConnectionController extends ValueNotifier<bool?> {
  DAVConnectionController({DAVClientFactory? createClient})
    : _createClient = createClient ?? DAVClient.new,
      super(null);

  final DAVClientFactory _createClient;

  DAVProps? _lastProps;
  bool _hasUpdated = false;
  int _requestId = 0;
  bool _disposed = false;

  DAVClient? client;

  Future<void> update(DAVProps? props) async {
    final nextClient = props == null ? null : _createClient(props);
    client = nextClient;

    final rawProps = props?.copyWith(fileName: '', directory: '');
    final rawLastProps = _lastProps?.copyWith(fileName: '', directory: '');
    final isSameCredentials = _hasUpdated && rawProps == rawLastProps;
    _lastProps = props;
    _hasUpdated = true;
    if (isSameCredentials) {
      return;
    }

    final requestId = ++_requestId;
    value = null;
    final result = await nextClient?.ping() ?? false;
    if (!_disposed && requestId == _requestId) {
      value = result;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestId++;
    super.dispose();
  }
}
