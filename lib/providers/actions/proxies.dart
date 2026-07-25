part of '../action.dart';

@Riverpod(keepAlive: true)
class ProxiesAction extends _$ProxiesAction {
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
      commonPrint.log('updateGroups error: $e');
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
        (entry) => availableProxies[entry.key]?.contains(entry.value) == true,
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
    setDelay(Delay(url: currentTestUrl, name: proxyState.proxyName, value: 0));
    await onDelayChanged?.call();
    late final Delay delay;
    try {
      delay = await coreController.getDelay(
        currentTestUrl,
        proxyState.proxyName,
      );
    } catch (_) {
      final currentDelay = ref.read(
        delayDataSourceProvider.select(
          (delayMap) => delayMap[currentTestUrl]?[proxyState.proxyName],
        ),
      );
      if (currentDelay == 0) {
        setDelay(
          Delay(url: currentTestUrl, name: proxyState.proxyName, value: -1),
        );
      }
      await onDelayChanged?.call();
      rethrow;
    }
    final currentDelay = ref.read(
      delayDataSourceProvider.select(
        (delayMap) => delayMap[currentTestUrl]?[proxyState.proxyName],
      ),
    );
    if (currentDelay == 0) {
      setDelay(delay);
    }
    await onDelayChanged?.call();
  }

  Future<void> testProxyDelays(
    List<Proxy> proxies,
    String? testUrl, {
    Duration batchTimeout = const Duration(seconds: 1),
    FutureOr<void> Function(Proxy proxy)? onDelayChanged,
  }) async {
    final batches = proxies.batch(100);
    for (final batch in batches) {
      await Future.wait(
        batch.map((proxy) async {
          try {
            await testProxyDelay(
              proxy,
              testUrl,
              onDelayChanged: () => onDelayChanged?.call(proxy),
            ).timeout(batchTimeout);
          } catch (e) {
            commonPrint.log('delayTest batch error: $e');
          }
        }),
      );
    }
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
