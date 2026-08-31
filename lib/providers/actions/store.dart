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
    final results = await Future.wait(
      pathsToDelete.map(_core.deleteManagedPath),
    );
    for (final error in results.where((error) => error.isNotEmpty)) {
      commonPrint.log(error, logLevel: LogLevel.warning);
    }
  }

  void savePreferencesDebounce() {
    debouncer.call(FunctionTag.savePreferences, () async {
      await preferences.saveConfig(ref.read(configProvider));
    });
  }

  Future<void> handleClear([Set<ResetDataType> types = allResetDataTypes]) {
    debouncer.cancel(FunctionTag.savePreferences);
    return ref
        .read(systemActionProvider.notifier)
        .handleReset(() => clearApplicationData(types));
  }
}
