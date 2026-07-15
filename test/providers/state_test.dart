import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  test('update params maps external controller settings to core config', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(updateParamsProvider).externalController, '');

    container
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith(
            externalController: '127.0.0.1:9191',
            secret: 'test-secret',
          ),
        );

    expect(
      container.read(updateParamsProvider).externalController,
      '127.0.0.1:9191',
    );
    expect(container.read(updateParamsProvider).secret, 'test-secret');

    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(externalController: '0.0.0.0:9191'));

    expect(
      container.read(updateParamsProvider).externalController,
      '0.0.0.0:9191',
    );
  });

  test('tray traffic state reuses the network speed setting', () async {
    final container = ProviderContainer(
      overrides: [selectedMapProvider.overrideWithValue(const {})],
    );
    addTearDown(container.dispose);
    final states = <({bool showNetworkSpeed, bool isStart})>[];
    final subscription = container.listen(
      trayStateProvider.select(
        (state) =>
            (showNetworkSpeed: state.showNetworkSpeed, isStart: state.isStart),
      ),
      (prev, next) => states.add(next),
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    container.read(runTimeProvider.notifier).update((_) => 0);
    await container.pump();
    container
        .read(vpnSettingProvider.notifier)
        .update((state) => state.copyWith(networkSpeedNotification: true));
    await container.pump();

    expect(states, [
      (showNetworkSpeed: false, isStart: false),
      (showNetworkSpeed: false, isStart: true),
      (showNetworkSpeed: true, isStart: true),
    ]);
  });

  test('tray groups retain the current selection used by the proxies view', () {
    final container = ProviderContainer(
      overrides: [selectedMapProvider.overrideWithValue(const {})],
    );
    addTearDown(container.dispose);
    const group = Group(
      name: 'Proxy',
      type: GroupType.Selector,
      now: 'Default',
      hidden: false,
    );

    container.read(groupsProvider.notifier).update((_) => [group]);

    expect(container.read(currentGroupsStateProvider).value.single.now, '');
    expect(container.read(trayStateProvider).groups.single.now, 'Default');

    container
        .read(groupsProvider.notifier)
        .update((_) => [group.copyWith(now: 'Updated')]);

    expect(container.read(trayStateProvider).groups.single.now, 'Updated');
  });
}
