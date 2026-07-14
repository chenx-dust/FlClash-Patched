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
}
