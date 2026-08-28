part of '../action.dart';

class _DelayTestTarget {
  const _DelayTestTarget({
    required this.proxyName,
    required this.testUrl,
    required this.key,
  });

  final String proxyName;
  final String testUrl;
  final String key;
}

class _DelayTestJob {
  _DelayTestJob(Iterable<String> keys, this.onDelayChanged)
    : held = keys.toSet();

  final Set<String> held;
  final FutureOr<void> Function()? onDelayChanged;
  bool cancelled = false;
}

@Riverpod(keepAlive: true)
class ProxiesAction extends _$ProxiesAction {
  CoreController get _core => ref.read(coreHandlerProvider);

  final TaskPool _delayTestPool = TaskPool(maxConcurrentDelayTests);

  final List<_DelayTestJob> _delayTestJobs = [];

  final Map<String, Future<Delay?>> _inFlightDelayTests = {};

  final Map<String, String> _pendingSelectedRollback = {};

  @override
  void build() {
    ref.listen(coreStatusProvider, (_, next) {
      if (next != CoreStatus.connected) {
        cancelDelayTests();
      }
    });
  }

  void cancelDelayTests() {
    for (final job in _delayTestJobs) {
      job.cancelled = true;
      job.held.clear();
    }
    _inFlightDelayTests.clear();
    ref.read(pendingDelayTestsProvider.notifier).clear();
  }

  void updateGroupsDebounce([Duration? duration]) {
    debouncer.call(FunctionTag.updateGroups, updateGroups, duration: duration);
  }

  void changeProxyDebounce(String groupName, String proxyName) {
    _pendingSelectedRollback.putIfAbsent(
      groupName,
      () => _currentSelectedName(groupName),
    );
    ref
        .read(profilesActionProvider.notifier)
        .updateCurrentSelectedMap(groupName, proxyName);
    debouncer.call((FunctionTag.changeProxy, groupName), (
      String groupName,
      String proxyName,
    ) async {
      await changeProxy(groupName: groupName, proxyName: proxyName);
      updateGroupsDebounce();
    }, args: [groupName, proxyName]);
  }

  String _currentSelectedName(String groupName) {
    return ref.read(currentProfileProvider)?.selectedMap[groupName] ?? '';
  }

  Future<void> resetProxySelection(String groupName) async {
    debouncer.cancel((FunctionTag.changeProxy, groupName));
    debouncer.cancel(FunctionTag.updateGroups);
    _pendingSelectedRollback.remove(groupName);
    await changeProxy(groupName: groupName, proxyName: '');
    await updateGroups();
  }

  Future<void> updateGroups() async {
    try {
      commonPrint.log('updateGroups');
      final profileId = ref.read(currentProfileProvider)?.id;
      final groups = await retry(
        task: () async {
          final sortType = ref.read(
            proxiesStyleSettingProvider.select((state) => state.sortType),
          );
          final delayMap = ref.read(delayDataSourceProvider);
          final testUrl = ref.read(
            appSettingProvider.select((state) => state.testUrl),
          );
          final selectedMap = ref.read(
            currentProfileProvider.select((state) => state?.selectedMap ?? {}),
          );
          return _core.getProxiesGroups(
            selectedMap: selectedMap,
            sortType: sortType,
            delayMap: delayMap,
            defaultTestUrl: testUrl,
          );
        },
        retryIf: (res) => res.isEmpty,
      );
      ref.read(groupsProvider.notifier).value = groups;
      _removeUnavailableSelections(profileId: profileId, groups: groups);
    } catch (e) {
      commonPrint.log(
        'updateGroups error: $e',
        logLevel: coreFailureLogLevel(e),
      );
    }
  }

  void _removeUnavailableSelections({
    required int? profileId,
    required List<Group> groups,
  }) {
    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile == null || currentProfile.id != profileId) {
      return;
    }
    final availableProxies = {
      for (final group in groups)
        group.name: group.all.map((proxy) => proxy.name).toSet(),
    };
    final selectedMap = Map<String, String>.fromEntries(
      currentProfile.selectedMap.entries.where(
        (entry) =>
            entry.value != compatibleProxyName &&
            availableProxies[entry.key]?.contains(entry.value) == true,
      ),
    );
    if (selectedMap.length == currentProfile.selectedMap.length) {
      return;
    }
    ref
        .read(profilesProvider.notifier)
        .put(currentProfile.copyWith(selectedMap: selectedMap));
  }

  void updateCurrentGroupName(String groupName) {
    final profile = ref.read(currentProfileProvider);
    if (profile == null || profile.currentGroupName == groupName) return;
    ref
        .read(profilesProvider.notifier)
        .put(profile.copyWith(currentGroupName: groupName));
  }

  void updateCurrentUnfoldSet(Set<String> value) {
    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile == null) return;
    ref
        .read(profilesProvider.notifier)
        .put(currentProfile.copyWith(unfoldSet: value));
  }

  void setDelay(Delay delay) {
    final key = delayTestKey(delay.url, delay.name);
    if (ref.read(pendingDelayTestsProvider).contains(key)) {
      return;
    }
    _setDelay(delay);
  }

  void _setDelay(Delay delay) {
    ref.read(delayDataSourceProvider.notifier).setDelay(delay);
  }

  Future<void> changeProxy({
    required String groupName,
    required String proxyName,
  }) async {
    final appSetting = ref.read(appSettingProvider);
    final currentProxyName = ref
        .read(groupsProvider)
        .getGroup(groupName)
        ?.realNow;
    final isSameProxy = proxyName.isNotEmpty && currentProxyName == proxyName;
    final closeConnections = appSetting.closeConnections && !isSameProxy;
    final params = ChangeProxyParams(
      groupName: groupName,
      proxyName: proxyName,
    );
    final profilesAction = ref.read(profilesActionProvider.notifier);
    final rollbackName =
        _pendingSelectedRollback.remove(groupName) ??
        _currentSelectedName(groupName);
    profilesAction.updateCurrentSelectedMap(groupName, proxyName);
    try {
      await _core.changeProxy(params, closeConnections: closeConnections);
    } catch (error) {
      commonPrint.log(
        'changeProxy($groupName -> $proxyName) failed: $error',
        logLevel: coreFailureLogLevel(error),
      );
      profilesAction.updateCurrentSelectedMap(groupName, rollbackName);
      dialogs.showNotifier(
        currentAppLocalizations.changeProxyFailedTip,
        level: MessageLevel.error,
      );
      return;
    }
    if (!isSameProxy &&
        !closeConnections &&
        appSetting.promptCloseConnections) {
      _showCloseConnectionsSnackBar(params);
    }
    ref.read(checkIpNumProvider.notifier).add();
  }

  void _showCloseConnectionsSnackBar(ChangeProxyParams params) {
    final context = globalState.navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }
    context.showSnackBar(
      currentAppLocalizations.closeConnectionsPrompt,
      persist: false,
      action: SnackBarAction(
        label: MaterialLocalizations.of(context).closeButtonTooltip,
        onPressed: () async {
          await _core.changeProxy(params, closeConnections: true);
        },
      ),
    );
  }

  Future<String> updateProvider(
    ExternalProvider provider, {
    bool showLoading = false,
  }) async {
    final operation = showLoading
        ? ref
              .read(updatingKeysProvider.notifier)
              .start(provider.updatingKey, scope: UpdatingScope.core)
        : null;
    try {
      final message = await _core.updateExternalProvider(
        providerName: provider.name,
      );
      if (message.isNotEmpty) return message;
      ref
          .read(providersProvider.notifier)
          .setProvider(await _core.getExternalProvider(provider.name));
      return '';
    } finally {
      if (operation != null) {
        ref
            .read(updatingKeysProvider.notifier)
            .stop(provider.updatingKey, operation);
      }
    }
  }

  Future<String> sideLoadExternalProvider(
    ExternalProvider provider,
    String data, {
    bool showLoading = false,
  }) async {
    final operation = showLoading
        ? ref
              .read(updatingKeysProvider.notifier)
              .start(provider.updatingKey, scope: UpdatingScope.core)
        : null;
    try {
      final message = await _core.sideLoadExternalProvider(
        providerName: provider.name,
        data: data,
      );
      if (message.isNotEmpty) return message;
      ref
          .read(providersProvider.notifier)
          .setProvider(await _core.getExternalProvider(provider.name));
      return '';
    } finally {
      if (operation != null) {
        ref
            .read(updatingKeysProvider.notifier)
            .stop(provider.updatingKey, operation);
      }
    }
  }

  Future<void> proxyDelayTest(Proxy proxy, [String? testUrl]) {
    return _runDelayTests([proxy], testUrl);
  }

  Future<void> delayTest(
    List<Proxy> proxies, [
    String? testUrl,
    FutureOr<void> Function()? onDelayChanged,
  ]) async {
    await _runDelayTests(proxies, testUrl, onDelayChanged);
    ref.read(sortNumProvider.notifier).add();
  }

  List<_DelayTestTarget> _resolveDelayTestTargets(
    List<Proxy> proxies,
    String? testUrl,
  ) {
    final groups = ref.read(groupsProvider);
    final selectedMap = ref.read(
      currentProfileProvider.select((state) => state?.selectedMap ?? {}),
    );
    final fallbackTestUrl = ref.read(realTestUrlProvider(testUrl));
    final seen = <String>{};
    final targets = <_DelayTestTarget>[];
    for (final proxy in proxies) {
      final state = computeRealSelectedProxyState(
        proxy.name,
        groups: groups,
        selectedMap: selectedMap,
      );
      if (state.proxyName.isEmpty) {
        continue;
      }
      final currentTestUrl = state.testUrl.takeFirstValid([fallbackTestUrl]);
      final key = delayTestKey(currentTestUrl, state.proxyName);
      if (!seen.add(key)) {
        continue;
      }
      targets.add(
        _DelayTestTarget(
          proxyName: state.proxyName,
          testUrl: currentTestUrl,
          key: key,
        ),
      );
    }
    return targets;
  }

  Future<void> _runDelayTests(
    List<Proxy> proxies,
    String? testUrl, [
    FutureOr<void> Function()? onDelayChanged,
  ]) async {
    final targets = _resolveDelayTestTargets(proxies, testUrl);
    if (targets.isEmpty) {
      return;
    }
    final pending = ref.read(pendingDelayTestsProvider.notifier);
    final job = _DelayTestJob(
      targets.map((target) => target.key),
      onDelayChanged,
    );
    _delayTestJobs.add(job);
    pending.acquire(job.held);
    await onDelayChanged?.call();
    try {
      await Future.wait(
        targets.map(
          (target) => _delayTestPool.run(() => _runDelayTest(job, target)),
        ),
      );
    } finally {
      _delayTestJobs.remove(job);
      final abandoned = job.held.toList();
      job.held.clear();
      pending.release(abandoned);
    }
  }

  Future<void> _runDelayTest(_DelayTestJob job, _DelayTestTarget target) async {
    if (job.cancelled) {
      return;
    }
    try {
      final delay = await _sharedDelayTest(target);
      if (delay != null && !job.cancelled) {
        _setDelay(delay);
      }
    } catch (error) {
      if (error is CoreMethodException && error.isCoreUnavailable) {
        job.cancelled = true;
      }
      commonPrint.log(
        'Delay test failed for ${target.proxyName}: $error',
        logLevel: coreFailureLogLevel(error),
      );
    } finally {
      if (job.held.remove(target.key)) {
        ref.read(pendingDelayTestsProvider.notifier).release([target.key]);
      }
      await job.onDelayChanged?.call();
    }
  }

  Future<Delay?> _sharedDelayTest(_DelayTestTarget target) {
    final pending = _inFlightDelayTests[target.key];
    if (pending != null) {
      return pending;
    }
    late final Future<Delay?> future;
    future = _core.getDelay(target.testUrl, target.proxyName).whenComplete(() {
      if (identical(_inFlightDelayTests[target.key], future)) {
        _inFlightDelayTests.remove(target.key);
      }
    });
    _inFlightDelayTests[target.key] = future;
    return future;
  }
}
