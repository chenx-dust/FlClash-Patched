part of '../action.dart';

@Riverpod(keepAlive: true)
class StoreAction extends _$StoreAction {
  CoreController get _core => ref.read(coreHandlerProvider);

  @override
  void build() {}

  Future<void> shakingStore() async {
    final profileIds = ref.read(profilesProvider).map((item) => item.id);
    final scripts = await ref.read(scriptsProvider.future);
    final scriptIds = scripts.map((item) => item.id);
    final pathsToDelete = await shakingProfileTask((
      profileIds: profileIds,
      scriptIds: scriptIds,
    ));
    await Future.wait(
      pathsToDelete.map((params) async {
        final error = await _core.deleteManagedPath(params);
        if (error.isNotEmpty) {
          throw MessageException(error);
        }
      }),
    );
  }

  void savePreferencesDebounce() {
    debouncer.call(FunctionTag.savePreferences, () async {
      await preferences.saveConfig(ref.read(configProvider));
    });
  }

  Future handleClear() async {
    debouncer.cancel(FunctionTag.savePreferences);
    final profileIds = ref
        .read(profilesProvider)
        .map((item) => item.id)
        .toSet();
    final providersDir = Directory(await appPath.getProvidersRootPath());
    if (await providersDir.exists()) {
      await for (final entity in providersDir.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final profileId = int.tryParse(p.basename(entity.path));
        if (profileId != null && profileId > 0) {
          profileIds.add(profileId);
        }
      }
    }
    final clearResults = await Future.wait(
      profileIds.map((profileId) async {
        try {
          return await _core.clearEffect(profileId);
        } catch (error) {
          return 'clearEffect($profileId) failed: $error';
        }
      }),
    );
    for (final error in clearResults.where((error) => error.isNotEmpty)) {
      commonPrint.log(error, logLevel: LogLevel.warning);
    }
    await preferences.clearPreferences();
    commonPrint.log('clear preferences');
    await database.close();
    await File(await appPath.databasePath).safeDelete(recursive: true);
    final profilesDir = Directory(await appPath.profilesPath);
    if (await profilesDir.exists()) {
      await for (final entity in profilesDir.list(followLinks: false)) {
        final error = await _core.deleteManagedPath(
          DeleteManagedPathParams(
            scope: ManagedPathScope.profiles,
            relativePath: p.relative(entity.path, from: profilesDir.path),
          ),
        );
        if (error.isNotEmpty) {
          commonPrint.log(error, logLevel: LogLevel.warning);
        }
      }
    }
    unawaited(ref.read(systemActionProvider.notifier).handleExit(false));
  }
}
