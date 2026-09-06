import 'dart:async';

import 'package:fl_clash/common/window.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNativeWindow {
  final List<String> calls = [];
  final List<(int?, String?)> activations = [];
  bool visible = true;
  Completer<void>? hideGate;

  WindowVisibilityController controller({
    Duration dockSettleDuration = const Duration(seconds: 1),
  }) {
    return WindowVisibilityController(
      showWindow: ({int? activationTimestamp, String? activationToken}) async {
        calls.add('show');
        activations.add((activationTimestamp, activationToken));
        visible = true;
      },
      hideWindow: () async {
        calls.add('hide');
        await hideGate?.future;
        visible = false;
      },
      isWindowVisible: () async => visible,
      setSkipTaskbar: (skip) async {
        calls.add(skip ? 'dock:off' : 'dock:on');
      },
      dockSettleDuration: dockSettleDuration,
    );
  }
}

void main() {
  test(
    'queued shows retain their own activation details without reusing them',
    () async {
      final native = _FakeNativeWindow()..hideGate = Completer<void>();
      final controller = native.controller(dockSettleDuration: Duration.zero);
      final hidden = controller.hide();
      final first = controller.show(
        activationTimestamp: 1234,
        activationToken: 'first-token',
      );
      final second = controller.show(
        activationTimestamp: 5678,
        activationToken: 'second-token',
      );
      final plain = controller.show();
      expect(native.activations, isEmpty);

      native.hideGate!.complete();
      await Future.wait([hidden, first, second, plain]);

      expect(native.activations, [
        (1234, 'first-token'),
        (5678, 'second-token'),
        (null, null),
      ]);
    },
  );

  testWidgets('a hide right after a show waits for the Dock policy to settle', (
    tester,
  ) async {
    final native = _FakeNativeWindow()..visible = false;
    final controller = native.controller();

    unawaited(controller.show());
    await controller.hide();

    expect(native.calls, ['show', 'dock:on', 'hide']);

    await tester.pump(const Duration(milliseconds: 999));
    expect(native.calls, ['show', 'dock:on', 'hide']);

    await tester.pump(const Duration(milliseconds: 1));
    expect(native.calls, ['show', 'dock:on', 'hide', 'dock:off']);
  });

  testWidgets(
    'a show during the settle window cancels the deferred Dock hide',
    (tester) async {
      final native = _FakeNativeWindow()..visible = false;
      final controller = native.controller();

      unawaited(controller.show());
      unawaited(controller.hide());
      await controller.show();
      await tester.pump(const Duration(seconds: 2));

      expect(native.calls, ['show', 'dock:on', 'hide', 'show', 'dock:on']);
      expect(native.visible, isTrue);
    },
  );

  testWidgets('a hide outside the settle window switches the Dock at once', (
    tester,
  ) async {
    final native = _FakeNativeWindow()..visible = false;
    final controller = native.controller();

    await controller.show();
    await tester.pump(const Duration(seconds: 1));
    await controller.hide();

    expect(native.calls, ['show', 'dock:on', 'hide', 'dock:off']);
  });

  test('a zero settle duration never defers the Dock switch', () async {
    final native = _FakeNativeWindow()..visible = false;
    final controller = native.controller(dockSettleDuration: Duration.zero);

    unawaited(controller.show());
    await controller.hide();

    expect(native.calls, ['show', 'dock:on', 'hide', 'dock:off']);
  });

  testWidgets('rapid toggles run one at a time and flip parity each press', (
    tester,
  ) async {
    final native = _FakeNativeWindow();
    native.hideGate = Completer<void>();
    final controller = native.controller();

    unawaited(controller.toggle());
    unawaited(controller.toggle());
    final last = controller.toggle();
    await tester.pump();

    expect(native.calls, ['hide']);

    native.hideGate!.complete();
    native.hideGate = null;
    await last;
    await tester.pump(const Duration(seconds: 2));

    expect(native.calls, [
      'hide',
      'dock:off',
      'show',
      'dock:on',
      'hide',
      'dock:off',
    ]);
    expect(native.visible, isFalse);
  });

  test('an idle controller starts a request without waiting a tick', () {
    final native = _FakeNativeWindow()..visible = false;
    final controller = native.controller(dockSettleDuration: Duration.zero);

    unawaited(controller.show());

    expect(native.calls, ['show']);
  });

  test('a failed step does not block later requests', () async {
    var failShow = true;
    final calls = <String>[];
    final controller = WindowVisibilityController(
      showWindow: ({int? activationTimestamp, String? activationToken}) async {
        if (failShow) {
          throw StateError('show failed');
        }
        calls.add('show');
      },
      hideWindow: () async => calls.add('hide'),
      isWindowVisible: () async => false,
      setSkipTaskbar: (skip) async => calls.add(skip ? 'dock:off' : 'dock:on'),
      dockSettleDuration: Duration.zero,
    );

    await expectLater(controller.show(), throwsStateError);
    failShow = false;
    await controller.hide();
    await controller.show();

    expect(calls, ['hide', 'dock:off', 'show', 'dock:on']);
  });
}
