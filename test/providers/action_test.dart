import 'dart:async';

import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
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
