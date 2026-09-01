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

@Riverpod(keepAlive: true)
class ProxiesAction extends _$ProxiesAction {
  CoreController get _core => ref.read(coreHandlerProvider);

  final TaskPool _delayTestPool = TaskPool(maxConcurrentDelayTests);
  final Map<String, Future<Delay?>> _pendingDelayTests = {};
  final Map<String, _DelayTestTarget> _pendingDelayTargets = {};
  int _delayTestGeneration = 0;

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
    final cancelledTargets = _pendingDelayTargets.values.toList();
    _delayTestGeneration++;
    _pendingDelayTests.clear();
    _pendingDelayTargets.clear();
    ref.read(pendingDelayTestsProvider.notifier).clear();
    final delays = ref.read(delayDataSourceProvider.notifier);
    for (final target in cancelledTargets) {
      delays.setDelay(
        Delay(url: target.testUrl, name: target.proxyName, value: -1),
      );
    }
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

  Future<void> resetProxySelection(String groupName) async {
    debouncer.cancel((FunctionTag.changeProxy, groupName));
    debouncer.cancel(FunctionTag.updateGroups);
    _pendingSelectedRollback.remove(groupName);
    await changeProxy(groupName: groupName, proxyName: '');
    await updateGroups();
  }

  String _currentSelectedName(String groupName) {
    return ref.read(currentProfileProvider)?.selectedMap[groupName] ?? '';
  }

  Future<void> updateGroups() async {
    try {
      commonPrint.log('updateGroups');
      final profileId = ref.read(currentProfileProvider)?.id;
      final groups = await retry<List<Group>>(
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
          try {
            return await _core.getProxiesGroups(
              selectedMap: selectedMap,
              sortType: sortType,
              delayMap: delayMap,
              defaultTestUrl: testUrl,
            );
          } catch (e) {
            commonPrint.log(
              'updateGroups error: $e',
              logLevel: coreFailureLogLevel(e),
            );
            return <Group>[];
          }
        },
        retryIf: (res) => res.isEmpty,
      );
      ref.read(groupsProvider.notifier).value = groups;
      if (groups.isNotEmpty) {
        _removeUnavailableSelections(profileId: profileId, groups: groups);
      }
    } catch (e) {
      // The Core failure path already runs inside the retry task above; a
      // throw here only means ref.read hit a disposed container or the
      // groupsProvider write itself failed.
      commonPrint.log(
        'updateGroups failed: $e',
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
        (entry) => availableProxies[entry.key]?.contains(entry.value) == true,
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
    if (_pendingDelayTests.containsKey(delayTestKey(delay.url, delay.name))) {
      return;
    }
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
    if (context == null || !context.mounted) return;
    context.showSnackBar(
      currentAppLocalizations.closeConnectionsPrompt,
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
    return _runDelayTests([proxy], testUrl, bumpSort: false);
  }

  Future<void> delayTest(
    List<Proxy> proxies, [
    String? testUrl,
    Duration uiTimeout = const Duration(seconds: 1),
  ]) {
    final operation = _runDelayTests(proxies, testUrl, bumpSort: true);
    return operation.timeout(uiTimeout, onTimeout: () {});
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
    String? testUrl, {
    required bool bumpSort,
  }) async {
    final generation = _delayTestGeneration;
    final targets = _resolveDelayTestTargets(proxies, testUrl);
    if (targets.isEmpty) {
      return;
    }
    await Future.wait(
      targets.map((target) async {
        try {
          await _scheduleDelayTest(target);
        } catch (error) {
          commonPrint.log(
            'Delay test failed for ${target.proxyName}: $error',
            logLevel: coreFailureLogLevel(error),
          );
        }
      }),
    );
    if (bumpSort && generation == _delayTestGeneration) {
      ref.read(sortNumProvider.notifier).add();
    }
  }

  Future<Delay?> _scheduleDelayTest(_DelayTestTarget target) {
    final pending = _pendingDelayTests[target.key];
    if (pending != null) {
      return pending;
    }
    final generation = _delayTestGeneration;
    final completer = Completer<Delay?>();
    final operation = completer.future;
    _pendingDelayTests[target.key] = operation;
    _pendingDelayTargets[target.key] = target;
    ref.read(pendingDelayTestsProvider.notifier).acquire([target.key]);
    ref
        .read(delayDataSourceProvider.notifier)
        .setDelay(Delay(url: target.testUrl, name: target.proxyName, value: 0));
    void release() {
      if (identical(_pendingDelayTests[target.key], operation)) {
        _pendingDelayTests.remove(target.key);
        _pendingDelayTargets.remove(target.key);
        ref.read(pendingDelayTestsProvider.notifier).release([target.key]);
      }
    }

    unawaited(
      operation.then<void>(
        (_) => release(),
        onError: (Object _, StackTrace _) => release(),
      ),
    );
    unawaited(
      _delayTestPool
          .run(() => _runDelayTest(target, generation))
          .then<void>(completer.complete, onError: completer.completeError),
    );
    return operation;
  }

  Future<Delay?> _runDelayTest(_DelayTestTarget target, int generation) async {
    if (generation != _delayTestGeneration) {
      return null;
    }
    try {
      final delay = await _core.getDelay(target.testUrl, target.proxyName);
      if (generation != _delayTestGeneration) {
        return null;
      }
      final result =
          delay ??
          Delay(url: target.testUrl, name: target.proxyName, value: -1);
      ref.read(delayDataSourceProvider.notifier).setDelay(result);
      return result;
    } catch (error) {
      if (error is CoreMethodException &&
          error.isCoreUnavailable &&
          generation == _delayTestGeneration) {
        cancelDelayTests();
        rethrow;
      }
      if (generation == _delayTestGeneration) {
        ref
            .read(delayDataSourceProvider.notifier)
            .setDelay(
              Delay(url: target.testUrl, name: target.proxyName, value: -1),
            );
      }
      rethrow;
    }
  }
}
