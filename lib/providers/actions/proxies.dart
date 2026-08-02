part of '../action.dart';

typedef _DelayTestKey = ({String proxyName, String testUrl});
typedef _DelayTestRequest = ({Completer<Delay> completer, _DelayTestKey key});

@Riverpod(keepAlive: true)
class ProxiesAction extends _$ProxiesAction {
  static const _delayTestConcurrency = maxConcurrentDelayTests;

  final Queue<_DelayTestRequest> _delayTestQueue = Queue();
  final Map<_DelayTestKey, Future<Delay>> _pendingDelayTests = {};
  int _runningDelayTests = 0;

  @override
  void build() {}

  void updateGroupsDebounce([Duration? duration]) {
    debouncer.call(FunctionTag.updateGroups, updateGroups, duration: duration);
  }

  void changeProxyDebounce(String groupName, String proxyName) {
    debouncer.call(FunctionTag.changeProxy, (
      String groupName,
      String proxyName,
    ) async {
      await changeProxy(groupName: groupName, proxyName: proxyName);
      updateGroupsDebounce();
    }, args: [groupName, proxyName]);
  }

  Future<void> resetProxySelection(String groupName) async {
    debouncer.cancel(FunctionTag.changeProxy);
    debouncer.cancel(FunctionTag.updateGroups);
    await changeProxy(groupName: groupName, proxyName: '');
    ref
        .read(profilesActionProvider.notifier)
        .updateCurrentSelectedMap(groupName, '');
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
          return coreController.getProxiesGroups(
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
      ref.read(groupsProvider.notifier).value = [];
    }
  }

  void _removeUnavailableSelections({
    required int? profileId,
    required List<Group> groups,
  }) {
    final currentProfile = ref.read(currentProfileProvider);
    if (currentProfile == null || currentProfile.id != profileId) return;
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
    if (selectedMap.length == currentProfile.selectedMap.length) return;
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
    final key = (proxyName: delay.name, testUrl: delay.url);
    // A manual test owns this key until its RPC result completes.
    if (_pendingDelayTests.containsKey(key)) {
      return;
    }
    _setDelay(delay);
  }

  void _setDelay(Delay delay) {
    ref.read(delayDataSourceProvider.notifier).setDelay(delay);
  }

  Future<void> testProxyDelay(
    Proxy proxy,
    String? testUrl, {
    FutureOr<void> Function()? onDelayChanged,
  }) async {
    final groups = ref.read(groupsProvider);
    final selectedMap = ref.read(
      currentProfileProvider.select((state) => state?.selectedMap ?? {}),
    );
    final proxyState = computeRealSelectedProxyState(
      proxy.name,
      groups: groups,
      selectedMap: selectedMap,
    );
    final currentTestUrl = proxyState.testUrl.takeFirstValid([
      ref.read(realTestUrlProvider(testUrl)),
    ]);
    if (proxyState.proxyName.isEmpty) {
      return;
    }
    final delayTest = _scheduleDelayTest((
      proxyName: proxyState.proxyName,
      testUrl: currentTestUrl,
    ));
    if (delayTest.started) {
      _setDelay(
        Delay(url: currentTestUrl, name: proxyState.proxyName, value: 0),
      );
    }
    await onDelayChanged?.call();
    try {
      await delayTest.future;
    } catch (error) {
      commonPrint.log(
        'Delay test failed for ${proxyState.proxyName}: $error',
        logLevel: coreFailureLogLevel(error),
      );
      await onDelayChanged?.call();
      rethrow;
    }
    await onDelayChanged?.call();
  }

  ({Future<Delay> future, bool started}) _scheduleDelayTest(_DelayTestKey key) {
    final pendingDelayTest = _pendingDelayTests[key];
    if (pendingDelayTest != null) {
      return (future: pendingDelayTest, started: false);
    }
    final completer = Completer<Delay>();
    final future = completer.future;
    _pendingDelayTests[key] = future;
    _delayTestQueue.add((completer: completer, key: key));
    _startDelayTests();
    return (future: future, started: true);
  }

  void _startDelayTests() {
    while (_runningDelayTests < _delayTestConcurrency &&
        _delayTestQueue.isNotEmpty) {
      final request = _delayTestQueue.removeFirst();
      _runningDelayTests++;
      unawaited(_runDelayTest(request));
    }
  }

  Future<void> _runDelayTest(_DelayTestRequest request) async {
    try {
      final delay = await coreController.getDelay(
        request.key.testUrl,
        request.key.proxyName,
      );
      _setDelay(delay);
      request.completer.complete(delay);
    } catch (error, stackTrace) {
      _setDelay(
        Delay(url: request.key.testUrl, name: request.key.proxyName, value: -1),
      );
      request.completer.completeError(error, stackTrace);
    } finally {
      if (identical(
        _pendingDelayTests[request.key],
        request.completer.future,
      )) {
        _pendingDelayTests.remove(request.key);
      }
      _runningDelayTests--;
      _startDelayTests();
    }
  }

  Future<void> testProxyDelays(
    List<Proxy> proxies,
    String? testUrl, {
    Duration uiTimeout = const Duration(seconds: 1),
    FutureOr<void> Function(Proxy proxy)? onDelayChanged,
  }) {
    final operation = _runProxyDelayTests(
      proxies,
      testUrl,
      onDelayChanged: onDelayChanged,
    );
    return operation.timeout(uiTimeout, onTimeout: () {});
  }

  Future<void> _runProxyDelayTests(
    List<Proxy> proxies,
    String? testUrl, {
    FutureOr<void> Function(Proxy proxy)? onDelayChanged,
  }) async {
    await Future.wait(
      proxies.map((proxy) async {
        try {
          await testProxyDelay(
            proxy,
            testUrl,
            onDelayChanged: () => onDelayChanged?.call(proxy),
          );
        } catch (error) {
          commonPrint.log('delayTest request error: $error');
        }
      }),
    );
    ref.read(sortNumProvider.notifier).add();
  }

  Future<void> changeProxy({
    required String groupName,
    required String proxyName,
  }) async {
    await coreController.changeProxy(
      ChangeProxyParams(groupName: groupName, proxyName: proxyName),
    );
    if (ref.read(appSettingProvider).closeConnections) {
      await coreController.closeConnections();
    } else {
      await coreController.resetConnections();
    }
    ref.read(checkIpNumProvider.notifier).add();
  }

  Future<String> updateProvider(
    ExternalProvider provider, {
    bool showLoading = false,
  }) async {
    try {
      if (showLoading) {
        ref.read(isUpdatingProvider(provider.updatingKey).notifier).value =
            true;
      }
      final message = await coreController.updateExternalProvider(
        providerName: provider.name,
      );
      if (message.isNotEmpty) return message;
      ref
          .read(providersProvider.notifier)
          .setProvider(await coreController.getExternalProvider(provider.name));
      return '';
    } finally {
      ref.read(isUpdatingProvider(provider.updatingKey).notifier).value = false;
    }
  }
}
