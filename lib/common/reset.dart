import 'dart:io';

import 'package:fl_clash/database/database.dart';
import 'package:flutter/foundation.dart';

import 'file.dart';
import 'path.dart';
import 'preferences.dart';
import 'print.dart';

enum ResetDataType { allData, settings, profilesAndScripts }

const allResetDataTypes = {
  ResetDataType.allData,
  ResetDataType.settings,
  ResetDataType.profilesAndScripts,
};

@visibleForTesting
Future<void> clearDirectoryContents(Directory directory) async {
  if (!await directory.exists()) {
    return;
  }
  await for (final entity in directory.list(followLinks: false)) {
    await entity.safeDelete(recursive: true);
  }
}

Future<void> clearApplicationData(Set<ResetDataType> types) async {
  if (types.isEmpty) {
    return;
  }
  if (types.contains(ResetDataType.allData)) {
    await preferences.clearPreferences();
    commonPrint.log('clear preferences');
    await database.close();
    await clearDirectoryContents(await appPath.dataDir.future);
    return;
  }
  if (types.contains(ResetDataType.settings)) {
    await preferences.clearPreferences();
    commonPrint.log('clear preferences');
  }
  if (types.contains(ResetDataType.profilesAndScripts)) {
    final config = await preferences.getConfig();
    if (config != null) {
      await preferences.saveConfig(config.copyWith(currentProfileId: null));
    }
    await database.close();
    await File(await appPath.databasePath).safeDelete(recursive: true);
    await Directory(await appPath.profilesPath).safeDelete(recursive: true);
    await Directory(await appPath.scriptsDirPath).safeDelete(recursive: true);
  }
}
