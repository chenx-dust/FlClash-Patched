import 'package:fl_clash/common/window.dart';
import 'package:fl_clash/common/function.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/config.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_retriever/screen_retriever.dart';

const _windowChannel = MethodChannel('window_manager');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;
  late bool isVisible;
  late bool isMaximized;
  late bool isFullScreen;
  late bool isMinimized;
  late Rect bounds;

  setUp(() {
    debouncer.cancel(FunctionTag.background);
    throttler.cancel(FunctionTag.foreground);
    calls = <String>[];
    isVisible = true;
    isMaximized = false;
    isFullScreen = false;
    isMinimized = false;
    bounds = const Rect.fromLTWH(20, 30, 1000, 800);
    globalState.isBackground.value = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowChannel, (call) async {
          calls.add(call.method);
          return switch (call.method) {
            'isVisible' => isVisible,
            'isMaximized' => isMaximized,
            'isFullScreen' => isFullScreen,
            'isMinimized' => isMinimized,
            'getBounds' => <String, double>{
              'x': bounds.left,
              'y': bounds.top,
              'width': bounds.width,
              'height': bounds.height,
            },
            _ => null,
          };
        });
  });

  tearDown(() {
    debouncer.cancel(FunctionTag.background);
    throttler.cancel(FunctionTag.foreground);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowChannel, null);
  });

  test('is a singleton so every caller drives the same window', () {
    expect(Window(), same(Window()));
  });

  testWidgets('show raises the window and puts it back on the taskbar', (
    tester,
  ) async {
    globalState.handleBackground();
    await Window().show();
    expect(globalState.isBackground.value, isFalse);

    expect(
      calls,
      containsAllInOrder(<String>['show', 'focus', 'setSkipTaskbar']),
    );
    await tester.pump(const Duration(seconds: 1));
  });

  test('hide drops the window off the taskbar', () async {
    await Window().hide();

    expect(calls, containsAllInOrder(<String>['hide', 'setSkipTaskbar']));
    expect(globalState.isBackground.value, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(globalState.isBackground.value, isTrue);
  });

  test('close asks the platform to close the window', () async {
    await Window().close();

    expect(calls, ['close']);
  });

  testWidgets('toggle hides a visible window and shows a hidden one', (
    tester,
  ) async {
    await Window().toggle();

    expect(
      calls,
      containsAllInOrder(<String>['isVisible', 'hide', 'setSkipTaskbar']),
    );

    calls.clear();
    isVisible = false;
    await Window().toggle();

    expect(
      calls,
      containsAllInOrder(<String>['isVisible', 'show', 'setSkipTaskbar']),
    );
    await tester.pump(const Duration(seconds: 1));
  });

  test(
    'normal geometry captures size without compositor-owned position',
    () async {
      const current = WindowProps(width: 800, height: 600, left: 90, top: 70);

      final geometry = await Window().captureNormalGeometry(current);

      expect(
        geometry,
        const WindowProps(width: 1000, height: 800, left: 90, top: 70),
      );
    },
  );

  test('maximized geometry is not captured', () async {
    isMaximized = true;

    expect(await Window().captureNormalGeometry(const WindowProps()), isNull);
    expect(calls, isNot(contains('getBounds')));
  });

  test('fullscreen and minimized geometry are not captured', () async {
    isFullScreen = true;
    expect(await Window().captureNormalGeometry(const WindowProps()), isNull);

    isFullScreen = false;
    isMinimized = true;
    expect(await Window().captureNormalGeometry(const WindowProps()), isNull);
  });

  group('restoredWindowPosition', () {
    // A 100% primary at physical 0..1920 and a 150% secondary to its right at
    // physical 1920..5760, as screen_retriever reports them on Windows.
    const displays = [
      Display(
        id: 'primary',
        size: Size(1920, 1080),
        visiblePosition: Offset.zero,
        visibleSize: Size(1920, 1040),
        scaleFactor: 1,
      ),
      Display(
        id: 'secondary',
        size: Size(2560, 1440),
        visiblePosition: Offset(1280, 0),
        visibleSize: Size(2560, 1400),
        scaleFactor: 1.5,
      ),
    ];

    test('puts a window saved on the 150% display back there from the '
        '100% one', () {
      const props = WindowProps(
        width: 680,
        height: 580,
        left: 1666,
        top: 100,
        scale: 1.5,
      );

      expect(
        restoredWindowPosition(props, displays: displays, currentScale: 1),
        const Offset(2499, 150),
      );
    });

    test('puts a window saved on the 100% display back there from the '
        '150% one', () {
      const props = WindowProps(
        width: 680,
        height: 580,
        left: 300,
        top: 200,
        scale: 1,
      );

      expect(
        restoredWindowPosition(props, displays: displays, currentScale: 1.5),
        const Offset(200, 200 / 1.5),
      );
    });

    test('reads a position saved without a scale in the current one', () {
      const props = WindowProps(width: 680, height: 580, left: 300, top: 200);

      expect(
        restoredWindowPosition(props, displays: displays, currentScale: 1),
        const Offset(300, 200),
      );
    });

    test('keeps a window hanging off the left edge while its title bar can '
        'still be dragged', () {
      const props = WindowProps(width: 680, height: 580, left: -200, top: 100);

      expect(
        restoredWindowPosition(props, displays: displays, currentScale: 1),
        const Offset(-200, 100),
      );
    });

    test('rejects a window whose title bar sits above every display', () {
      const props = WindowProps(width: 680, height: 580, left: 100, top: -500);

      expect(
        restoredWindowPosition(props, displays: displays, currentScale: 1),
        isNull,
      );
    });

    test('rejects a window with only a sliver of title bar left on screen', () {
      const props = WindowProps(width: 680, height: 580, left: -620, top: 100);

      expect(
        restoredWindowPosition(props, displays: displays, currentScale: 1),
        isNull,
      );
    });

    test('rejects a position off every display', () {
      const props = WindowProps(width: 680, height: 580, left: 9000, top: 100);

      expect(
        restoredWindowPosition(props, displays: displays, currentScale: 1),
        isNull,
      );
    });

    test('compares logical values directly when no scale applies', () {
      const props = WindowProps(width: 680, height: 580, left: 2000, top: 100);

      expect(
        restoredWindowPosition(props, displays: displays),
        const Offset(2000, 100),
      );
    });
  });
}
