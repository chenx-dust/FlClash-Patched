import 'dart:async';

import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
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
    late _MockCoreHandlerInterface coreHandler;

    setUp(() {
      coreHandler = _MockCoreHandlerInterface();
      CoreController.resetInstance();
      CoreController.test(coreHandler);
    });

    tearDown(CoreController.resetInstance);

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

    test('applies the profile before updating one resource', () async {
      final events = <String>[];
      when(() => coreHandler.updateGeoData(GeoResource.MMDB.name)).thenAnswer((
        _,
      ) async {
        events.add('update');
        return '';
      });
      final container = ProviderContainer(
        overrides: [
          setupActionProvider.overrideWith(() => _RecordingSetupAction(events)),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(geoResourceActionProvider.notifier)
          .updateGeoResource(GeoResource.MMDB);

      expect(events, ['apply', 'update']);
      verify(() => coreHandler.updateGeoData(GeoResource.MMDB.name)).called(1);
    });

    test('applies the profile once before updating all resources', () async {
      final events = <String>[];
      when(() => coreHandler.updateGeoData(any())).thenAnswer((
        invocation,
      ) async {
        events.add('update:${invocation.positionalArguments.single}');
        return '';
      });
      final container = ProviderContainer(
        overrides: [
          setupActionProvider.overrideWith(() => _RecordingSetupAction(events)),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(geoResourceActionProvider.notifier)
          .updateAllGeoResources();

      expect(events.first, 'apply');
      expect(events.where((event) => event == 'apply'), hasLength(1));
      expect(events.skip(1).toSet(), {
        for (final geoResource in GeoResource.values)
          'update:${geoResource.name}',
      });
      verify(
        () => coreHandler.updateGeoData(any()),
      ).called(GeoResource.values.length);
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

      expect(coreAction.lifecycleRestartCount, 1);
      expect(setupAction.setRunningCount, 0);
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

        expect(coreAction.lifecycleRestartCount, 1);
        expect(setupAction.setRunningCount, 1);
        expect(setupAction.applyProfileCount, 0);
      },
    );

    test(
      'coalesces concurrent restart requests into one lifecycle restart',
      () async {
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
        final restartCompleter = Completer<CoreLifecycleResult>();
        coreAction.restartCompleter = restartCompleter;

        final first = coreAction.restartCore();
        final second = coreAction.restartCore();
        await Future<void>.delayed(Duration.zero);

        expect(coreAction.lifecycleRestartCount, 1);
        restartCompleter.complete(_restartResult);
        await Future.wait([first, second]);

        expect(setupAction.applyProfileCount, 1);
      },
    );

    test('reapplies the latest request without restarting twice', () async {
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
      final restartCompleter = Completer<CoreLifecycleResult>();
      final firstApplyStarted = Completer<void>();
      final firstApplyCompleter = Completer<void>();
      coreAction.restartCompleter = restartCompleter;
      setupAction.firstApplyStarted = firstApplyStarted;
      setupAction.firstApplyCompleter = firstApplyCompleter;

      final first = coreAction.restartCore();
      await Future<void>.delayed(Duration.zero);
      restartCompleter.complete(_restartResult);
      await firstApplyStarted.future;

      final second = coreAction.restartCore();
      firstApplyCompleter.complete();
      await Future.wait([first, second]);

      expect(coreAction.lifecycleRestartCount, 1);
      expect(setupAction.applyProfileCount, 2);
    });

    test('surfaces a failed restart to its caller as a rejection', () async {
      final container = ProviderContainer(
        overrides: [
          coreActionProvider.overrideWith(_TestCoreAction.new),
          setupActionProvider.overrideWith(_TestSetupAction.new),
        ],
      );
      addTearDown(container.dispose);
      final coreAction =
          container.read(coreActionProvider.notifier) as _TestCoreAction;
      final restartCompleter = Completer<CoreLifecycleResult>();
      coreAction.restartCompleter = restartCompleter;

      final restart = coreAction.restartCore();
      restartCompleter.completeError(StateError('core is gone'));

      await expectLater(restart, throwsA(isA<StateError>()));
      expect(container.read(coreStatusProvider), CoreStatus.disconnected);

      // The failed operation must not latch: a later restart still runs.
      coreAction.restartCompleter = null;
      await coreAction.restartCore();
      expect(coreAction.lifecycleRestartCount, 2);
      expect(container.read(coreStatusProvider), CoreStatus.connected);
    });
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

        final startFuture = action.setRunning(true);
        final initialRunTime = container.read(runTimeProvider)!;
        await Future<void>.delayed(const Duration(milliseconds: 1100));

        expect(container.read(runTimeProvider), greaterThan(initialRunTime));
        expect(commonAction.updateTrafficCount, greaterThanOrEqualTo(2));

        startCompleter.complete(true);
        await startFuture;

        expect(action.transitions, [true]);
        await action.setRunning(false);
      });

      test('serializes listener changes while latest start owns UI', () async {
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
        await action.setRunning(true);
        action.transitions.clear();
        action.applyProfileDebounceCount = 0;
        action.stopCompleter = stopCompleter;

        final stopFuture = action.setRunning(false);
        await Future<void>.delayed(Duration.zero);
        expect(action.transitions, [false]);

        final startFuture = action.setRunning(true);

        expect(container.read(runTimeProvider), isNotNull);

        stopCompleter.complete(true);
        await Future.wait([stopFuture, startFuture]);

        expect(action.transitions, [false, true]);
        expect(container.read(runTimeProvider), isNotNull);
        expect(container.read(isStartProvider), isTrue);
        expect(action.applyProfileDebounceCount, 1);
        expect(action.resetCoreTrafficCount, 0);

        await action.setRunning(false);
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

        final startFuture = action.setRunning(true);
        await Future<void>.delayed(Duration.zero);
        expect(action.transitions, [true]);

        final stopFuture = action.setRunning(false);
        expect(container.read(runTimeProvider), isNull);

        startCompleter.complete(true);
        await Future.wait([startFuture, stopFuture]);

        expect(action.transitions, [true, false]);
        expect(container.read(runTimeProvider), isNull);
        expect(container.read(isStartProvider), isFalse);
        expect(action.applyProfileDebounceCount, 0);
        expect(action.resetCoreTrafficCount, 1);
      });

      test('skips an intermediate stop when a newer start is queued', () async {
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

        final firstStart = action.setRunning(true);
        await Future<void>.delayed(Duration.zero);
        final stop = action.setRunning(false);
        final latestStart = action.setRunning(true);

        startCompleter.complete(true);
        await Future.wait([firstStart, stop, latestStart]);

        expect(action.transitions, [true, true]);
        expect(container.read(isStartProvider), isTrue);
        expect(action.applyProfileDebounceCount, 1);
        expect(action.resetCoreTrafficCount, 0);

        await action.setRunning(false);
      });

      test('stale initialization cannot start after a newer stop', () async {
        final container = ProviderContainer(
          overrides: [
            initProvider.overrideWithBuild((_, _) => true),
            commonActionProvider.overrideWith(_RaceCommonAction.new),
            setupActionProvider.overrideWith(_InitializingSetupAction.new),
          ],
        );
        addTearDown(container.dispose);
        final action =
            container.read(setupActionProvider.notifier)
                as _InitializingSetupAction;

        final start = action.setRunning(true, initialize: true);
        final stop = action.setRunning(false);
        await stop;

        expect(action.transitions, [false]);
        expect(container.read(isStartProvider), isFalse);

        action.continueInitialization();
        await start;

        expect(action.transitions, [false]);
        expect(container.read(isStartProvider), isFalse);
      });

      test(
        'keeps suspended startup local until the listener resumes',
        () async {
          final container = ProviderContainer(
            overrides: [
              initProvider.overrideWithBuild((_, _) => true),
              suspendProvider.overrideWithValue(true),
              commonActionProvider.overrideWith(_RaceCommonAction.new),
              setupActionProvider.overrideWith(_RaceSetupAction.new),
            ],
          );
          addTearDown(container.dispose);
          final action =
              container.read(setupActionProvider.notifier) as _RaceSetupAction;

          await action.setRunning(true);

          expect(action.transitions, isEmpty);
          expect(container.read(isStartProvider), isTrue);
          expect(action.applyProfileDebounceCount, 1);

          await action.setRunning(false);
          expect(action.transitions, [false]);
        },
      );
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

    test('reopens authorization and propagates a failed restart', () async {
      late _AuthorizationSetupAction setupAction;
      final container = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWithValue(null),
          setupActionProvider.overrideWith(() {
            setupAction = _AuthorizationSetupAction([AuthorizeCode.success]);
            return setupAction;
          }),
          coreActionProvider.overrideWith(_FailingRestartCoreAction.new),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith.tun(enable: true));
      container.read(setupActionProvider);
      container.read(coreActionProvider);

      await expectLater(
        setupAction.applyProfile(force: true),
        throwsA(same(_restartFailure)),
      );

      expect(
        container.read(authorizedTunEnableProvider),
        TunAuthorizationState.none,
      );
    });

    test('requests admin authorization once per app lifecycle', () async {
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

      expect(await setupAction.requestAdmin(true), isTrue);
      expect(setupAction.authorizationRequestCount, 1);
      expect(
        container.read(authorizedTunEnableProvider),
        TunAuthorizationState.unauthorized,
      );
    });

    test('keeps tun disabled while authorization stays unauthorized', () async {
      late _AuthorizationSetupAction setupAction;
      final container = ProviderContainer(
        overrides: [
          setupActionProvider.overrideWith(() {
            setupAction = _AuthorizationSetupAction([AuthorizeCode.error]);
            return setupAction;
          }),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith.tun(enable: true));
      container.read(setupActionProvider);

      await setupAction.requestAdmin(true);

      expect(container.read(autoSetSystemDnsStateProvider).a, isFalse);
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

    test(
      'deduplicates resolved proxy and URL across overlapping requests',
      () async {
        const directProxy = Proxy(name: 'Node A', type: 'Shadowsocks');
        const groupProxy = Proxy(name: 'Automatic', type: 'URLTest');
        const group = Group(
          type: GroupType.URLTest,
          name: 'Automatic',
          now: 'Node A',
          testUrl: 'https://default.test',
        );
        final response = Completer<Delay>();
        when(
          () => coreHandler.asyncTestDelay('https://default.test', 'Node A'),
        ).thenAnswer((_) => response.future);
        container.read(groupsProvider.notifier).value = [group];
        final changedProxies = <Proxy>[];
        final action = container.read(proxiesActionProvider.notifier);

        final firstRequest = action.testProxyDelays(
          [directProxy, groupProxy, directProxy],
          'https://default.test',
          uiTimeout: const Duration(seconds: 30),
          onDelayChanged: changedProxies.add,
        );
        final overlappingRequest = action.testProxyDelays(
          [groupProxy],
          'https://default.test',
          uiTimeout: const Duration(seconds: 30),
          onDelayChanged: changedProxies.add,
        );

        verify(
          () => coreHandler.asyncTestDelay('https://default.test', 'Node A'),
        ).called(1);

        response.complete(
          const Delay(url: 'https://default.test', name: 'Node A', value: 42),
        );
        await Future.wait([firstRequest, overlappingRequest]);

        expect(
          container.read(
            delayDataSourceProvider,
          )['https://default.test']?['Node A'],
          42,
        );
        expect(
          changedProxies.where((proxy) => proxy == directProxy),
          hasLength(4),
        );
        expect(
          changedProxies.where((proxy) => proxy == groupProxy),
          hasLength(4),
        );
      },
    );

    test('allows retry after a shared delay request fails', () async {
      const proxy = Proxy(name: 'Node A', type: 'Shadowsocks');
      var requestCount = 0;
      when(
        () => coreHandler.asyncTestDelay('https://default.test', 'Node A'),
      ).thenAnswer((_) async {
        requestCount++;
        if (requestCount == 1) {
          throw TimeoutException('delay test');
        }
        return const Delay(
          url: 'https://default.test',
          name: 'Node A',
          value: 42,
        );
      });
      final action = container.read(proxiesActionProvider.notifier);

      await action.testProxyDelays(
        [proxy, proxy],
        'https://default.test',
        uiTimeout: const Duration(seconds: 30),
      );

      expect(requestCount, 1);
      expect(
        container.read(
          delayDataSourceProvider,
        )['https://default.test']?['Node A'],
        -1,
      );

      await action.testProxyDelay(proxy, 'https://default.test');

      expect(requestCount, 2);
      expect(
        container.read(
          delayDataSourceProvider,
        )['https://default.test']?['Node A'],
        42,
      );

      container
          .read(proxiesActionProvider.notifier)
          .setDelay(
            const Delay(url: 'https://default.test', name: 'Node A', value: 43),
          );
      expect(
        container.read(
          delayDataSourceProvider,
        )['https://default.test']?['Node A'],
        43,
      );
    });

    test('manual delay result wins over core events while pending', () async {
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
          .read(proxiesActionProvider.notifier)
          .setDelay(
            const Delay(url: 'https://default.test', name: 'Node A', value: -1),
          );
      expect(
        container.read(
          delayDataSourceProvider,
        )['https://default.test']?['Node A'],
        0,
      );
      response.complete(
        const Delay(url: 'https://default.test', name: 'Node A', value: 42),
      );
      await testFuture;

      expect(observedDelays, [0, 42]);
      expect(
        container.read(
          delayDataSourceProvider,
        )['https://default.test']?['Node A'],
        42,
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
            uiTimeout: const Duration(seconds: 30),
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

    test(
      'returns after the UI timeout while requests respect the concurrency limit',
      () async {
        final proxies = List.generate(
          51,
          (index) => Proxy(name: 'Node $index', type: 'Shadowsocks'),
        );
        final responses = {
          for (final proxy in proxies) proxy.name: Completer<Delay>(),
        };
        final requestedNames = <String>[];
        final firstBatchStarted = Completer<void>();
        final secondBatchStarted = Completer<void>();
        final lastResultPublished = Completer<void>();
        when(
          () => coreHandler.asyncTestDelay('https://default.test', any()),
        ).thenAnswer((invocation) {
          final proxyName = invocation.positionalArguments[1] as String;
          requestedNames.add(proxyName);
          if (requestedNames.length == maxConcurrentDelayTests) {
            firstBatchStarted.complete();
          }
          if (proxyName == proxies.last.name) {
            secondBatchStarted.complete();
          }
          return responses[proxyName]!.future;
        });

        final uiFuture = container
            .read(proxiesActionProvider.notifier)
            .testProxyDelays(
              proxies,
              'https://default.test',
              uiTimeout: Duration.zero,
              onDelayChanged: (proxy) {
                final delay = container.read(
                  delayDataSourceProvider.select(
                    (delayMap) => delayMap['https://default.test']?[proxy.name],
                  ),
                );
                if (proxy == proxies.last &&
                    delay == 42 &&
                    !lastResultPublished.isCompleted) {
                  lastResultPublished.complete();
                }
              },
            );

        await firstBatchStarted.future;
        await uiFuture;
        expect(requestedNames, hasLength(maxConcurrentDelayTests));
        expect(requestedNames, isNot(contains(proxies.last.name)));
        expect(
          container.read(
            delayDataSourceProvider,
          )['https://default.test']?[proxies.last.name],
          0,
        );

        container
            .read(proxiesActionProvider.notifier)
            .setDelay(
              Delay(
                url: 'https://default.test',
                name: proxies.last.name,
                value: -1,
              ),
            );
        expect(
          container.read(
            delayDataSourceProvider,
          )['https://default.test']?[proxies.last.name],
          0,
        );

        for (final proxy in proxies.take(maxConcurrentDelayTests)) {
          responses[proxy.name]!.complete(
            Delay(url: 'https://default.test', name: proxy.name, value: 42),
          );
        }
        await secondBatchStarted.future;

        responses[proxies.last.name]!.complete(
          Delay(
            url: 'https://default.test',
            name: proxies.last.name,
            value: 42,
          ),
        );
        await lastResultPublished.future;
      },
    );

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
            'Empty': 'COMPATIBLE',
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
            all: [
              'Available',
              'Changed',
              'Empty',
              'Node A',
              'Node B',
              'COMPATIBLE',
            ],
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
              'Empty': {
                'name': 'Empty',
                'type': 'Selector',
                'all': ['COMPATIBLE'],
              },
              'Node A': {'name': 'Node A', 'type': 'Shadowsocks'},
              'Node B': {'name': 'Node B', 'type': 'Shadowsocks'},
              'COMPATIBLE': {'name': 'COMPATIBLE', 'type': 'Compatible'},
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
          'Empty',
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
  int lifecycleRestartCount = 0;
  Completer<CoreLifecycleResult>? restartCompleter;

  @override
  Future<void> initCore() async {}

  @override
  Future<CoreLifecycleResult> restartLifecycle() {
    lifecycleRestartCount++;
    return restartCompleter?.future ?? Future.value(_restartResult);
  }
}

class _TestSetupAction extends SetupAction {
  int setRunningCount = 0;
  int applyProfileCount = 0;
  Completer<void>? firstApplyStarted;
  Completer<void>? firstApplyCompleter;

  @override
  Future<void> setRunning(bool running, {bool initialize = false}) async {
    setRunningCount++;
  }

  @override
  Future<void> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    applyProfileCount++;
    if (applyProfileCount == 1) {
      firstApplyStarted?.complete();
      await firstApplyCompleter?.future;
    }
  }
}

const _restartResult = CoreLifecycleResult(
  revision: 1,
  outcome: CoreLifecycleOutcome.applied,
);

class _RecordingSetupAction extends SetupAction {
  final List<String> events;

  _RecordingSetupAction(this.events);

  @override
  Future<void> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    expect(silence, isTrue);
    events.add('apply');
  }
}

class _RestartRecordingCoreAction extends CoreAction {
  int restartCount = 0;

  @override
  Future<void> restartCore() async {
    restartCount++;
  }
}

class _FailingRestartCoreAction extends CoreAction {
  @override
  Future<void> restartCore() async {
    throw _restartFailure;
  }
}

final _restartFailure = Exception('restart failed');

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
  int resetCoreTrafficCount = 0;
  final transitions = <bool>[];
  Completer<bool>? startCompleter;
  Completer<bool>? stopCompleter;

  @override
  void applyProfileDebounce({bool silence = false, bool force = false}) {
    applyProfileDebounceCount++;
  }

  @override
  Future<bool> setCoreRunning(bool running) async {
    transitions.add(running);
    return running
        ? await startCompleter?.future ?? true
        : await stopCompleter?.future ?? true;
  }

  @override
  void resetCoreTraffic() {
    resetCoreTrafficCount++;
  }
}

class _InitializingSetupAction extends _RaceSetupAction {
  final _initializationCompleter = Completer<void>();

  void continueInitialization() {
    _initializationCompleter.complete();
  }

  @override
  Future<void> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    await _initializationCompleter.future;
    await preloadInvoke?.call();
  }
}

class _RaceCommonAction extends CommonAction {
  int updateTrafficCount = 0;

  @override
  Future<void> updateTraffic() async {
    updateTrafficCount++;
  }
}
