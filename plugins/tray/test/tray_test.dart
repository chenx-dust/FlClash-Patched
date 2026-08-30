import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray/tray.dart';

const MethodChannel _channel = MethodChannel('tray');
const StandardMethodCodec _codec = StandardMethodCodec();

TraySpec _spec({List<TrayMenuItem> menu = const []}) {
  return TraySpec(
    icon: const TrayIcon.asset('assets/icon.ico'),
    toolTip: 'FlClash',
    menu: menu,
  );
}

Future<void> _emit(String method, Object? arguments) {
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        _channel.name,
        _codec.encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late bool showResult;
  Completer<void>? showGate;

  int showCount() => calls.where((call) => call.method == 'show').length;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    calls = [];
    showResult = true;
    showGate = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          if (call.method == 'show') {
            await showGate?.future;
            return showResult;
          }
          return true;
        });
    Tray.instance.resetForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    Tray.instance.resetForTesting();
    debugDefaultTargetPlatformOverride = null;
  });

  test('a rejected show stays invisible and is retried', () async {
    showResult = false;
    await Tray.instance.show(_spec());

    expect(showCount(), 1);
    expect(Tray.instance.isVisible, isFalse);

    showResult = true;
    await Tray.instance.show(_spec());

    expect(showCount(), 2);
    expect(Tray.instance.isVisible, isTrue);
  });

  test(
    'an unchanged payload is suppressed only after an accepted show',
    () async {
      showResult = true;
      await Tray.instance.show(_spec());
      await Tray.instance.show(_spec());

      expect(showCount(), 1);

      showResult = false;
      await Tray.instance.show(_spec(menu: const [TrayMenuAction(label: 'a')]));
      await Tray.instance.show(_spec(menu: const [TrayMenuAction(label: 'a')]));

      expect(showCount(), 3);
    },
  );

  test('titles queued behind a stalled call collapse to the newest', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await Tray.instance.show(_spec());

    final gate = Completer<void>();
    showGate = gate;
    final stalled = Tray.instance.show(
      _spec(menu: const [TrayMenuAction(label: 'a')]),
    );
    unawaited(Tray.instance.setTitle('1'));
    unawaited(Tray.instance.setTitle('2'));
    final settled = Tray.instance.setTitle('3');
    gate.complete();
    await stalled;
    await settled;

    final titles = calls
        .where((call) => call.method == 'setTitle')
        .map((call) => (call.arguments as Map)['title'])
        .toList();
    expect(
      titles,
      ['3'],
      reason:
          'a native call that blocks the queue must not replay every title '
          'that piled up behind it',
    );
  });

  test('menu selection dispatches only for known integer ids', () async {
    var selected = 0;
    await Tray.instance.show(
      _spec(
        menu: [TrayMenuAction(label: 'a', onSelected: () => selected++)],
      ),
    );

    await _emit('onMenuItemSelected', <String, Object?>{'id': 1024});
    expect(selected, 1);

    await _emit('onMenuItemSelected', <String, Object?>{'id': 4096});
    await _emit('onMenuItemSelected', <String, Object?>{'id': '1024'});
    await _emit('onMenuItemSelected', null);
    expect(selected, 1);
  });

  test('updates a visible menu item by its stable key', () async {
    await Tray.instance.show(
      _spec(
        menu: const [TrayMenuAction(key: 'delay-test', label: 'Delay test')],
      ),
    );

    expect(
      await Tray.instance.updateMenuItem(
        key: 'delay-test',
        label: 'Retest',
        enabled: false,
        checked: true,
        sublabel: '42 ms',
        sublabelStyle: TrayMenuSublabelStyle.badge,
      ),
      isTrue,
    );

    final update = calls.last;
    expect(update.method, 'updateMenuItem');
    expect(update.arguments, {
      'key': 'delay-test',
      'label': 'Retest',
      'enabled': false,
      'checked': true,
      'sublabel': '42 ms',
      'sublabelStyle': 'badge',
    });
  });

  test('does not update menu items while hidden', () async {
    expect(
      await Tray.instance.updateMenuItem(key: 'delay-test', enabled: false),
      isFalse,
    );
    expect(calls, isEmpty);
  });

  test(
    'propagates a native unknown-key result without invalidating show',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call);
            return call.method == 'updateMenuItem' ? false : true;
          });
      final spec = _spec(
        menu: const [TrayMenuAction(key: 'known', label: 'Known')],
      );
      await Tray.instance.show(spec);

      expect(
        await Tray.instance.updateMenuItem(key: 'missing', enabled: false),
        isFalse,
      );
      await Tray.instance.show(spec);

      expect(showCount(), 1);
    },
  );

  test('openMenu encodes the optional Windows owner preference', () async {
    await Tray.instance.show(_spec());

    await Tray.instance.openMenu();
    await Tray.instance.openMenu(bringAppToFront: true);

    final openCalls = calls.where((call) => call.method == 'openMenu').toList();
    expect(openCalls.map((call) => call.arguments), [
      {'bringAppToFront': false},
      {'bringAppToFront': true},
    ]);
  });

  test('openMenu calls stay ordered behind an in-flight show', () async {
    await Tray.instance.show(_spec());
    final gate = Completer<void>();
    showGate = gate;

    final stalled = Tray.instance.show(
      _spec(menu: const [TrayMenuAction(label: 'changed')]),
    );
    final defaultOwner = Tray.instance.openMenu();
    final appOwner = Tray.instance.openMenu(bringAppToFront: true);
    gate.complete();

    await Future.wait([stalled, defaultOwner, appOwner]);
    final orderedCalls = calls.skip(1).toList();
    expect(orderedCalls.map((call) => call.method), [
      'show',
      'openMenu',
      'openMenu',
    ]);
    expect(orderedCalls.skip(1).map((call) => call.arguments), [
      {'bringAppToFront': false},
      {'bringAppToFront': true},
    ]);
  });

  test('an open macOS menu does not block live item updates', () async {
    final menuClosed = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          if (call.method == 'openMenu') {
            await menuClosed.future;
          }
          return true;
        });
    await Tray.instance.show(
      _spec(
        menu: const [TrayMenuAction(key: 'delay', label: 'Delay test')],
      ),
    );

    final open = Tray.instance.openMenu();
    await Future<void>.delayed(Duration.zero);
    final update = Tray.instance.updateMenuItem(key: 'delay', enabled: false);
    await update;

    expect(calls.map((call) => call.method), [
      'show',
      'openMenu',
      'updateMenuItem',
    ]);
    menuClosed.complete();
    await open;
  });

  test('a rejected show keeps callbacks for the visible menu', () async {
    var oldSelected = 0;
    var newSelected = 0;
    await Tray.instance.show(
      _spec(
        menu: [TrayMenuAction(label: 'old', onSelected: () => oldSelected++)],
      ),
    );

    showResult = false;
    await Tray.instance.show(
      _spec(
        menu: [TrayMenuAction(label: 'new', onSelected: () => newSelected++)],
      ),
    );
    await _emit('onMenuItemSelected', <String, Object?>{'id': 1024});

    expect([oldSelected, newSelected], [1, 0]);
  });

  test(
    'an unchanged accepted show refreshes callbacks without a native show',
    () async {
      var oldSelected = 0;
      var newSelected = 0;
      await Tray.instance.show(
        _spec(
          menu: [
            TrayMenuAction(label: 'item', onSelected: () => oldSelected++),
          ],
        ),
      );
      await Tray.instance.show(
        _spec(
          menu: [
            TrayMenuAction(label: 'item', onSelected: () => newSelected++),
          ],
        ),
      );
      await _emit('onMenuItemSelected', <String, Object?>{'id': 1024});

      expect(showCount(), 1);
      expect([oldSelected, newSelected], [0, 1]);
    },
  );
}
