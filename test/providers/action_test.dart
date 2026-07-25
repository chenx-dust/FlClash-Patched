import 'dart:async';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

void main() {
  group('ProfilesAction', () {
    test('keeps edited profile data when remote update fails', () async {
      final original = Profile.normal(label: 'old label', url: 'bad-url');
      final edited = original.copyWith(
        label: 'new label',
        url: 'still-bad-url',
      );
      final container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => null),
          profilesProvider.overrideWith(() => _TestProfiles([original])),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(profilesProvider).getProfile(original.id),
        original,
      );

      await expectLater(
        container.read(profilesActionProvider.notifier).updateProfile(edited),
        throwsA(anything),
      );

      final profile = container.read(profilesProvider).getProfile(original.id);
      expect(profile?.label, edited.label);
      expect(profile?.url, edited.url);
    });

    test('updates selection, inserts first profile, and reorders profiles', () {
      final first = Profile.normal(label: 'First');
      final second = Profile.normal(label: 'Second');
      final container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => first.id),
          profilesProvider.overrideWith(() => _TestProfiles([first])),
        ],
      );
      addTearDown(container.dispose);
      final action = container.read(profilesActionProvider.notifier);

      action.updateCurrentSelectedMap('Group', 'Proxy');
      final updatedFirst = container.read(profilesProvider).single;
      expect(updatedFirst.selectedMap['Group'], 'Proxy');

      action.updateCurrentSelectedMap('Group', 'Proxy');
      expect(container.read(profilesProvider), hasLength(1));

      container.read(currentProfileIdProvider.notifier).value = null;
      action.putProfile(second);
      expect(container.read(currentProfileIdProvider), second.id);
      expect(container.read(profilesProvider), [updatedFirst, second]);

      action.reorder([second, updatedFirst]);
      expect(container.read(profilesProvider), [second, updatedFirst]);
    });

    test(
      'skips profile updates that are disabled, fresh, or file-based',
      () async {
        final profiles = [
          Profile.normal(label: 'Disabled').copyWith(autoUpdate: false),
          Profile.normal(label: 'Fresh').copyWith(
            autoUpdate: true,
            lastUpdateDate: DateTime.now().add(const Duration(days: 1)),
          ),
          Profile.normal(label: 'File').copyWith(
            autoUpdate: true,
            lastUpdateDate: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];
        final container = ProviderContainer(
          overrides: [
            currentProfileIdProvider.overrideWithBuild((_, _) => null),
            profilesProvider.overrideWith(() => _TestProfiles(profiles)),
          ],
        );
        addTearDown(container.dispose);
        final action = container.read(profilesActionProvider.notifier);

        await action.autoUpdateProfiles();
        await action.updateProfiles();

        expect(container.read(profilesProvider), profiles);
      },
    );

    test('setProfileAndAutoApply stores a non-current profile', () {
      final current = Profile.normal(label: 'Current');
      final other = Profile.normal(label: 'Other');
      final container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => current.id),
          profilesProvider.overrideWith(() => _TestProfiles([current])),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(profilesActionProvider.notifier)
          .setProfileAndAutoApply(other);

      expect(container.read(profilesProvider), [current, other]);
      expect(container.read(currentProfileIdProvider), current.id);
    });
  });

  group('GeoResourceAction', () {
    test('GeoResource has correct updatingKey', () {
      expect(GeoResource.MMDB.updatingKey, 'geo_resource_MMDB');
      expect(GeoResource.ASN.updatingKey, 'geo_resource_ASN');
      expect(GeoResource.GEOIP.updatingKey, 'geo_resource_GEOIP');
      expect(GeoResource.GEOSITE.updatingKey, 'geo_resource_GEOSITE');
    });

    test('IsUpdating provider works with geo resource key', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final key = GeoResource.MMDB.updatingKey;
      expect(container.read(isUpdatingProvider(key)), false);

      container.read(isUpdatingProvider(key).notifier).value = true;
      expect(container.read(isUpdatingProvider(key)), true);

      container.read(isUpdatingProvider(key).notifier).value = false;
      expect(container.read(isUpdatingProvider(key)), false);
    });

    test('updates valid resource URLs and rejects malformed URLs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final action = container.read(geoResourceActionProvider.notifier);

      expect(
        () => action.updateGeoResourceUrl(GeoResource.MMDB, 'not-a-url'),
        throwsA('Invalid url'),
      );

      const url = 'https://example.com/Country.mmdb';
      action.updateGeoResourceUrl(GeoResource.MMDB, url);
      expect(
        container.read(patchClashConfigProvider).geoXUrl[GeoResource.MMDB],
        url,
      );
    });
  });

  group('CoreAction', () {
    test('applies the profile after restarting a stopped core', () async {
      final container = ProviderContainer(
        overrides: [
          coreActionProvider.overrideWith(_TestCoreAction.new),
          setupActionProvider.overrideWith(_TestSetupAction.new),
        ],
      );
      addTearDown(container.dispose);
      final coreAction =
          container.read(coreActionProvider.notifier) as _TestCoreAction;
      final setupAction =
          container.read(setupActionProvider.notifier) as _TestSetupAction;

      await coreAction.restartCore();

      expect(coreAction.reconnectCount, 1);
      expect(setupAction.updateStatusCount, 0);
      expect(setupAction.applyProfileCount, 1);
    });

    test(
      'restores the started state after restarting a running core',
      () async {
        final container = ProviderContainer(
          overrides: [
            coreActionProvider.overrideWith(_TestCoreAction.new),
            setupActionProvider.overrideWith(_TestSetupAction.new),
          ],
        );
        addTearDown(container.dispose);
        container.read(runTimeProvider.notifier).value = 0;
        final coreAction =
            container.read(coreActionProvider.notifier) as _TestCoreAction;
        final setupAction =
            container.read(setupActionProvider.notifier) as _TestSetupAction;

        await coreAction.restartCore();

        expect(coreAction.reconnectCount, 1);
        expect(setupAction.updateStatusCount, 1);
        expect(setupAction.applyProfileCount, 0);
      },
    );
  });

  group('SetupAction', () {
    group('rapid status changes', () {
      test('updates runtime and traffic while core start is pending', () async {
        final startCompleter = Completer<bool>();
        final container = ProviderContainer(
          overrides: [
            initProvider.overrideWithBuild((_, _) => true),
            commonActionProvider.overrideWith(_RaceCommonAction.new),
            setupActionProvider.overrideWith(_RaceSetupAction.new),
          ],
        );
        addTearDown(container.dispose);
        final action =
            container.read(setupActionProvider.notifier) as _RaceSetupAction;
        final commonAction =
            container.read(commonActionProvider.notifier) as _RaceCommonAction;
        action.startCompleter = startCompleter;

        final startFuture = action.updateStatus(true);
        final initialRunTime = container.read(runTimeProvider)!;
        await Future<void>.delayed(const Duration(milliseconds: 1100));

        expect(container.read(runTimeProvider), greaterThan(initialRunTime));
        expect(commonAction.updateTrafficCount, greaterThanOrEqualTo(2));

        startCompleter.complete(true);
        await startFuture;

        await action.handleStop();
      });

      test('newer start prevents stale stop cleanup', () async {
        final stopCompleter = Completer<bool>();
        final container = ProviderContainer(
          overrides: [
            initProvider.overrideWithBuild((_, _) => true),
            commonActionProvider.overrideWith(_RaceCommonAction.new),
            setupActionProvider.overrideWith(_RaceSetupAction.new),
          ],
        );
        addTearDown(container.dispose);
        final action =
            container.read(setupActionProvider.notifier) as _RaceSetupAction;
        action.stopCompleter = stopCompleter;
        action.startTime = DateTime.now().subtract(const Duration(seconds: 1));
        container.read(runTimeProvider.notifier).value = 1;

        final stopFuture = action.updateStatus(false);
        await Future<void>.delayed(Duration.zero);
        final startFuture = action.updateStatus(true);
        await startFuture;

        expect(action.startTime, isNotNull);
        expect(container.read(runTimeProvider), isNotNull);
        expect(action.applyProfileDebounceCount, 1);

        stopCompleter.complete(true);
        await stopFuture;

        expect(action.startTime, isNotNull);
        expect(container.read(runTimeProvider), isNotNull);
        expect(container.read(isStartProvider), isTrue);

        await action.handleStop();
      });

      test('newer stop prevents stale start continuation', () async {
        final startCompleter = Completer<bool>();
        final container = ProviderContainer(
          overrides: [
            initProvider.overrideWithBuild((_, _) => true),
            commonActionProvider.overrideWith(_RaceCommonAction.new),
            setupActionProvider.overrideWith(_RaceSetupAction.new),
          ],
        );
        addTearDown(container.dispose);
        final action =
            container.read(setupActionProvider.notifier) as _RaceSetupAction;
        action.startCompleter = startCompleter;

        final startFuture = action.updateStatus(true);
        await Future<void>.delayed(Duration.zero);
        await action.updateStatus(false);

        expect(action.startTime, isNull);
        expect(container.read(runTimeProvider), isNull);

        startCompleter.complete(true);
        await startFuture;

        expect(action.startTime, isNull);
        expect(container.read(runTimeProvider), isNull);
        expect(container.read(isStartProvider), isFalse);
        expect(action.applyProfileDebounceCount, 0);
      });
    });

    test(
      'restarts core after newly granting admin during config update',
      () async {
        late _AuthorizationSetupAction setupAction;
        late _RestartRecordingCoreAction coreAction;
        final container = ProviderContainer(
          overrides: [
            setupActionProvider.overrideWith(() {
              setupAction = _AuthorizationSetupAction([AuthorizeCode.success]);
              return setupAction;
            }),
            coreActionProvider.overrideWith(() {
              coreAction = _RestartRecordingCoreAction();
              return coreAction;
            }),
          ],
        );
        addTearDown(container.dispose);
        container
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.tun(enable: true));
        container.read(setupActionProvider);
        container.read(coreActionProvider);

        await setupAction.updateConfig();

        expect(setupAction.authorizationRequestCount, 1);
        expect(
          container.read(authorizedTunEnableProvider),
          TunAuthorizationState.authorized,
        );
        expect(coreAction.restartCount, 1);
      },
    );

    test('retries admin authorization after a failed attempt', () async {
      late _AuthorizationSetupAction setupAction;
      final container = ProviderContainer(
        overrides: [
          setupActionProvider.overrideWith(() {
            setupAction = _AuthorizationSetupAction([
              AuthorizeCode.error,
              AuthorizeCode.success,
            ]);
            return setupAction;
          }),
        ],
      );
      addTearDown(container.dispose);
      container.read(setupActionProvider);

      expect(await setupAction.requestAdmin(true), isTrue);
      expect(
        container.read(authorizedTunEnableProvider),
        TunAuthorizationState.unauthorized,
      );

      expect(await setupAction.requestAdmin(true), isFalse);
      expect(setupAction.authorizationRequestCount, 2);
      expect(
        container.read(authorizedTunEnableProvider),
        TunAuthorizationState.authorized,
      );
    });
  });

  group('ProxiesAction delay tests', () {
    late _MockCoreHandlerInterface coreHandler;
    late ProviderContainer container;

    setUp(() {
      coreHandler = _MockCoreHandlerInterface();
      CoreController.resetInstance();
      CoreController.test(coreHandler);
      container = ProviderContainer(
        overrides: [
          currentProfileIdProvider.overrideWithBuild((_, _) => null),
          profilesProvider.overrideWith(() => _TestProfiles([])),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      CoreController.resetInstance();
    });

    test(
      'resolves the real proxy and stores loading and result states',
      () async {
        const proxy = Proxy(name: 'Automatic', type: 'URLTest');
        const group = Group(
          type: GroupType.URLTest,
          name: 'Automatic',
          now: 'Node A',
          testUrl: 'https://group.test',
        );
        final response = Completer<Delay>();
        when(
          () => coreHandler.asyncTestDelay('https://group.test', 'Node A'),
        ).thenAnswer((_) => response.future);
        container.read(groupsProvider.notifier).value = [group];
        final observedDelays = <int?>[];

        final testFuture = container
            .read(proxiesActionProvider.notifier)
            .testProxyDelay(
              proxy,
              'https://default.test',
              onDelayChanged: () {
                observedDelays.add(
                  container.read(
                    delayDataSourceProvider,
                  )['https://group.test']?['Node A'],
                );
              },
            );

        expect(
          container.read(
            delayDataSourceProvider,
          )['https://group.test']?['Node A'],
          0,
        );
        expect(observedDelays, [0]);

        response.complete(
          const Delay(url: 'https://group.test', name: 'Node A', value: 42),
        );
        await testFuture;

        expect(
          container.read(
            delayDataSourceProvider,
          )['https://group.test']?['Node A'],
          42,
        );
        expect(observedDelays, [0, 42]);
        verify(
          () => coreHandler.asyncTestDelay('https://group.test', 'Node A'),
        ).called(1);
      },
    );

    test('publishes a result already stored by the core event', () async {
      const proxy = Proxy(name: 'Node A', type: 'Shadowsocks');
      final response = Completer<Delay>();
      when(
        () => coreHandler.asyncTestDelay('https://default.test', 'Node A'),
      ).thenAnswer((_) => response.future);
      final observedDelays = <int?>[];

      final testFuture = container
          .read(proxiesActionProvider.notifier)
          .testProxyDelay(
            proxy,
            'https://default.test',
            onDelayChanged: () {
              observedDelays.add(
                container.read(
                  delayDataSourceProvider,
                )['https://default.test']?['Node A'],
              );
            },
          );

      container
          .read(delayDataSourceProvider.notifier)
          .setDelay(
            const Delay(url: 'https://default.test', name: 'Node A', value: 41),
          );
      response.complete(
        const Delay(url: 'https://default.test', name: 'Node A', value: 42),
      );
      await testFuture;

      expect(observedDelays, [0, 41]);
      expect(
        container.read(
          delayDataSourceProvider,
        )['https://default.test']?['Node A'],
        41,
      );
    });

    test('publishes each result without waiting for slower proxies', () async {
      const fastProxy = Proxy(name: 'Fast', type: 'Shadowsocks');
      const slowProxy = Proxy(name: 'Slow', type: 'Shadowsocks');
      final fastResponse = Completer<Delay>();
      final slowResponse = Completer<Delay>();
      final fastResultPublished = Completer<void>();
      when(
        () => coreHandler.asyncTestDelay('https://default.test', 'Fast'),
      ).thenAnswer((_) => fastResponse.future);
      when(
        () => coreHandler.asyncTestDelay('https://default.test', 'Slow'),
      ).thenAnswer((_) => slowResponse.future);

      final groupTestFuture = container
          .read(proxiesActionProvider.notifier)
          .testProxyDelays(
            [fastProxy, slowProxy],
            'https://default.test',
            batchTimeout: const Duration(seconds: 30),
            onDelayChanged: (proxy) {
              final delay = container.read(
                delayDataSourceProvider.select(
                  (delayMap) => delayMap['https://default.test']?[proxy.name],
                ),
              );
              if (proxy.name == fastProxy.name &&
                  delay == 42 &&
                  !fastResultPublished.isCompleted) {
                fastResultPublished.complete();
              }
            },
          );

      fastResponse.complete(
        const Delay(url: 'https://default.test', name: 'Fast', value: 42),
      );
      await fastResultPublished.future;

      expect(
        container.read(
          delayDataSourceProvider,
        )['https://default.test']?[fastProxy.name],
        42,
      );
      expect(
        container.read(
          delayDataSourceProvider,
        )['https://default.test']?[slowProxy.name],
        0,
      );

      slowResponse.complete(
        const Delay(url: 'https://default.test', name: 'Slow', value: 84),
      );
      await groupTestFuture;
    });

    test('publishes timeout state for a failed delay request', () async {
      const proxy = Proxy(name: 'Node A', type: 'Shadowsocks');
      when(
        () => coreHandler.asyncTestDelay('https://default.test', 'Node A'),
      ).thenAnswer((_) async => throw TimeoutException('delay test'));
      final observedDelays = <int?>[];

      final testFuture = container
          .read(proxiesActionProvider.notifier)
          .testProxyDelay(
            proxy,
            'https://default.test',
            onDelayChanged: () {
              observedDelays.add(
                container.read(
                  delayDataSourceProvider,
                )['https://default.test']?['Node A'],
              );
            },
          );

      await expectLater(testFuture, throwsA(isA<TimeoutException>()));
      expect(observedDelays, [0, -1]);
      expect(
        container.read(
          delayDataSourceProvider,
        )['https://default.test']?['Node A'],
        -1,
      );
    });
  });

  group('ProxiesAction group updates', () {
    late _MockCoreHandlerInterface coreHandler;

    setUp(() {
      coreHandler = _MockCoreHandlerInterface();
      CoreController.resetInstance();
      CoreController.test(coreHandler);
    });

    tearDown(CoreController.resetInstance);

    test(
      'removes unavailable proxy selections from the current profile',
      () async {
        final profile = Profile.normal().copyWith(
          selectedMap: {
            'Available': 'Node A',
            'Changed': 'Removed Node',
            'Removed Group': 'Node C',
          },
        );
        final container = ProviderContainer(
          overrides: [
            currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
            profilesProvider.overrideWith(() => _TestProfiles([profile])),
          ],
        );
        addTearDown(container.dispose);
        when(() => coreHandler.getProxies()).thenAnswer(
          (_) async => ProxiesData(
            all: ['Available', 'Changed', 'Node A', 'Node B'],
            proxies: Map<String, dynamic>.from({
              'Available': {
                'name': 'Available',
                'type': 'Selector',
                'all': ['Node A'],
              },
              'Changed': {
                'name': 'Changed',
                'type': 'Selector',
                'all': ['Node B'],
              },
              'Node A': {'name': 'Node A', 'type': 'Shadowsocks'},
              'Node B': {'name': 'Node B', 'type': 'Shadowsocks'},
            }),
          ),
        );

        await container.read(proxiesActionProvider.notifier).updateGroups();

        expect(
          container.read(profilesProvider).getProfile(profile.id)?.selectedMap,
          {'Available': 'Node A'},
        );
        expect(container.read(groupsProvider).map((group) => group.name), [
          'Available',
          'Changed',
        ]);
      },
    );
  });
}

class _TestProfiles extends Profiles {
  final List<Profile> initial;

  _TestProfiles(this.initial);

  @override
  List<Profile> build() => initial;

  @override
  void put(Profile profile) {
    final next = List<Profile>.from(state);
    final index = next.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      next.add(profile);
    } else {
      next[index] = profile;
    }
    state = next;
  }

  @override
  Future<void> del(int id) async {
    state = state.where((profile) => profile.id != id).toList();
  }

  @override
  void reorder(List<Profile> profiles) {
    state = List.of(profiles);
  }
}

class _TestCoreAction extends CoreAction {
  int reconnectCount = 0;

  @override
  Future<void> reconnectCore() async {
    reconnectCount++;
  }
}

class _TestSetupAction extends SetupAction {
  int updateStatusCount = 0;
  int applyProfileCount = 0;

  @override
  Future<void> updateStatus(bool isStart, {bool isInit = false}) async {
    updateStatusCount++;
  }

  @override
  Future<void> applyProfile({
    bool silence = false,
    bool force = false,
    VoidCallback? preloadInvoke,
  }) async {
    applyProfileCount++;
  }
}

class _RestartRecordingCoreAction extends CoreAction {
  int restartCount = 0;

  @override
  Future<void> restartCore([bool start = false]) async {
    restartCount++;
  }
}

class _AuthorizationSetupAction extends SetupAction {
  final List<AuthorizeCode> authorizationResults;
  int authorizationRequestCount = 0;

  _AuthorizationSetupAction(this.authorizationResults);

  @override
  Future<AuthorizeCode> authorizeCore() async {
    return authorizationResults[authorizationRequestCount++];
  }
}

class _RaceSetupAction extends SetupAction {
  int applyProfileDebounceCount = 0;
  Completer<bool>? startCompleter;
  Completer<bool>? stopCompleter;

  @override
  void applyProfileDebounce({bool silence = false, bool force = false}) {
    applyProfileDebounceCount++;
  }

  @override
  Future<bool> startCoreListener() async {
    return await startCompleter?.future ?? true;
  }

  @override
  Future<bool> stopCoreListener() async {
    return await stopCompleter?.future ?? true;
  }

  @override
  void resetCoreTraffic() {}
}

class _RaceCommonAction extends CommonAction {
  int updateTrafficCount = 0;

  @override
  Future<void> updateTraffic() async {
    updateTrafficCount++;
  }
}
