import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/common/app_ports.dart';
import 'package:fl_clash/common/compute.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod/misc.dart' show ProviderListenable;
import 'package:tray/tray.dart';

import '../helpers/test_profiles.dart';

const _channel = MethodChannel('tray');

class _TrayProxiesAction extends ProxiesAction {
  final selections = <({String groupName, String proxyName})>[];
  final testedGroups = <List<Proxy>>[];

  @override
  void build() {}

  @override
  Future<void> changeProxy({
    required String groupName,
    required String proxyName,
  }) async {
    selections.add((groupName: groupName, proxyName: proxyName));
  }

  @override
  Future<void> delayTest(
    List<Proxy> proxies, [
    String? testUrl,
    Duration uiTimeout = const Duration(seconds: 1),
    FutureOr<void> Function(Set<String> proxyNames)? onDelayChanged,
  ]) async {
    testedGroups.add(proxies);
    for (final proxy in proxies) {
      ref
          .read(delayDataSourceProvider.notifier)
          .setDelay(Delay(url: testUrl!, name: proxy.name, value: 42));
    }
    await onDelayChanged?.call(proxies.map((proxy) => proxy.name).toSet());
  }
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => root;
}

TrayState _trayState({
  bool isStart = false,
  bool tunEnable = false,
  bool systemProxy = false,
  bool autoLaunch = false,
  bool showNetworkSpeed = false,
  Mode mode = Mode.rule,
  List<Group> groups = const [],
  Map<String, String> selectedMap = const {},
}) {
  return TrayState(
    mode: mode,
    port: 7890,
    autoLaunch: autoLaunch,
    systemProxy: systemProxy,
    tunEnable: tunEnable,
    isStart: isStart,
    groups: groups,
    selectedMap: selectedMap,
    showNetworkSpeed: showNetworkSpeed,
    monochromeTrayIcon: false,
  );
}

List<Map<Object?, Object?>> _items(MethodCall? call) {
  final menu = (call?.arguments as Map?)?['menu'] as List?;
  return menu?.cast<Map<Object?, Object?>>() ?? const [];
}

List<String> _labels(MethodCall? call) {
  return _items(call).map((item) => item['label']).whereType<String>().toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late ProviderContainer container;
  late AppTray tray;

  late Directory root;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('tray_menu_test');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    await AppLocalizations.load(const Locale('en'));
  });

  tearDownAll(() {
    // The shared system temp dir is not exclusively ours; another suite running
    // alongside this one can take the tree out from under the teardown, either
    // before the check or between the check and the delete.
    try {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    } on FileSystemException {
      return;
    }
  });

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    calls = [];
    tray = AppTray.forPlatform(isMacOS: true, isWindows: false);
    container = ProviderContainer();
    Tray.instance.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    container.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  MethodCall? showCall() {
    for (final call in calls.reversed) {
      if (call.method == 'show') {
        return call;
      }
    }
    return null;
  }

  Future<void> update(TrayState trayState, {AppTray? on}) {
    return (on ?? tray).update(
      trayState: trayState,
      traffic: const Traffic(),
      read: container.read,
    );
  }

  test(
    'profile submenu switches profiles and disables unavailable updates',
    () async {
      const remote = Profile(
        id: 1,
        label: 'Remote',
        url: 'https://example.com/profile.yaml',
        autoUpdateDuration: Duration(days: 1),
      );
      final local = remote.copyWith(id: 2, label: 'Local', url: '');
      container.dispose();
      container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([remote, local])),
        ],
      );
      container.listen(currentProfileIdProvider, (_, _) {});
      container.read(currentProfileIdProvider.notifier).value = remote.id;

      List<Map> profileItems() =>
          (_items(showCall()).singleWhere(
                    (item) => item['label'] == currentAppLocalizations.profile,
                  )['items']
                  as List)
              .cast<Map>();

      await update(_trayState());
      expect(profileItems().first['checked'], isTrue);
      expect(profileItems().last['enabled'], isTrue);
      final operation = container
          .read(updatingKeysProvider.notifier)
          .start(remote.updatingKey);
      await update(_trayState());
      expect(profileItems().last['enabled'], isFalse);
      container
          .read(updatingKeysProvider.notifier)
          .stop(remote.updatingKey, operation);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            _channel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('onMenuItemSelected', {'id': profileItems()[1]['id']}),
            ),
            (_) {},
          );
      expect(container.read(currentProfileIdProvider), local.id);
      await update(_trayState());
      expect(profileItems()[1]['checked'], isTrue);
      expect(profileItems().last['enabled'], isFalse);
      container.read(currentProfileIdProvider.notifier).value = null;
      await update(_trayState());
      expect(profileItems().last['enabled'], isFalse);
    },
  );

  for (final minimized in [false, true]) {
    testWidgets(
      'show menu forwards activation details (minimized: $minimized)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        tray = AppTray.forPlatform(isMacOS: false, isWindows: false);
        globalState.container = container;
        const windowChannel = MethodChannel('window_manager');
        final windowCalls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(windowChannel, (call) async {
              windowCalls.add(call);
              return call.method == 'isMinimized' ? minimized : null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(windowChannel, null);
        });
        try {
          await tester.runAsync(() => update(_trayState()));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
        final showItem = _items(showCall()).first;

        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              _channel.name,
              const StandardMethodCodec().encodeMethodCall(
                MethodCall('onMenuItemSelected', {
                  'id': showItem['id'],
                  'activationTimestamp': 1234,
                  'activationToken': 'wayland-token',
                }),
              ),
              (_) {},
            );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));

        final activation = windowCalls.singleWhere(
          (call) => call.method == (minimized ? 'restore' : 'show'),
        );
        expect(activation.arguments['activationTimestamp'], 1234);
        expect(activation.arguments['activationToken'], 'wayland-token');
        expect(
          windowCalls.where(
            (call) =>
                call.arguments is Map &&
                call.arguments['activationToken'] == 'wayland-token',
          ),
          hasLength(1),
        );
      },
    );
  }

  test(
    'SystemAction.updateTray builds the menu without reading itself',
    () async {
      globalState.container = container;
      trayPort = tray;
      addTearDown(() => trayPort = null);

      await container.read(systemActionProvider.notifier).updateTray();

      expect(showCall(), isNotNull);
      expect(_labels(showCall()), contains(currentAppLocalizations.exit));
    },
  );

  test('keeps TUN and system proxy available while stopped', () async {
    await update(_trayState());

    final labels = _labels(showCall());
    final items = _items(showCall());
    final l10n = currentAppLocalizations;
    expect(labels, contains(l10n.show));
    expect(labels, contains(l10n.start));
    expect(labels, contains(l10n.autoLaunch));
    expect(labels, contains(l10n.copyEnvVar));
    expect(labels, contains(l10n.exit));
    expect(
      items.singleWhere((item) => item['label'] == l10n.tun)['checked'],
      isFalse,
    );
    expect(
      items.singleWhere((item) => item['label'] == l10n.systemProxy)['checked'],
      isFalse,
    );
  });

  test('adds TUN and system proxy toggles once the core is running', () async {
    await update(_trayState(isStart: true));

    final labels = _labels(showCall());
    final l10n = currentAppLocalizations;
    expect(labels, contains(l10n.stop), reason: 'start flips to stop');
    expect(labels, contains(l10n.tun));
    expect(labels, contains(l10n.systemProxy));
  });

  test('shows hotkey shortcuts for mode, copy, delay, and update', () async {
    container.listen(hotKeyActionsProvider, (_, _) {});
    container.read(hotKeyActionsProvider.notifier).value = [
      HotKeyAction(
        action: HotAction.ruleMode,
        key: PhysicalKeyboardKey.keyA.usbHidUsage,
        modifiers: const {KeyboardModifier.control},
      ),
      HotKeyAction(
        action: HotAction.copyEnv,
        key: PhysicalKeyboardKey.keyC.usbHidUsage,
        modifiers: const {KeyboardModifier.control, KeyboardModifier.shift},
      ),
    ];

    await update(_trayState());

    final l10n = currentAppLocalizations;
    final items = _items(showCall());
    final rule = items.singleWhere((item) => item['label'] == l10n.rule);
    expect(rule['keyEquivalent'], 'a');
    expect(rule['keyEquivalentModifiers'], ['control']);
    final copy = items.singleWhere((item) => item['label'] == l10n.copyEnvVar);
    expect(copy['keyEquivalent'], 'c');
    expect(copy['keyEquivalentModifiers'], containsAll(['control', 'shift']));
    expect(
      items.map((item) => item['label']),
      containsAll([l10n.actionDelayTest, l10n.actionUpdateProfiles]),
    );

    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tray = AppTray.forPlatform(isMacOS: false, isWindows: true);
    await update(_trayState());
    expect(calls.where((call) => call.method == 'show').length, 2);
    final windowsItems = _items(showCall());
    expect(
      windowsItems.map((item) => item['label']).toList(),
      contains('${l10n.rule}\tCtrl+A'),
    );
    expect(
      windowsItems.singleWhere(
        (item) => item['label'] == '${l10n.copyEnvVar}\tCtrl+Shift+C',
      ),
      isNotNull,
    );
  });

  test('keeps the network speed title visible while stopped', () async {
    await update(_trayState(isStart: true, showNetworkSpeed: true));

    expect(
      _labels(showCall()),
      isNot(contains(currentAppLocalizations.speedStatistics)),
    );
    expect(calls.where((call) => call.method == 'setTitle'), hasLength(1));

    calls.clear();
    await tray.updateTitle(
      showNetworkSpeed: true,
      isStart: false,
      traffic: const Traffic(up: 1, down: 2),
    );

    final titleCall = calls.singleWhere((call) => call.method == 'setTitle');
    expect((titleCall.arguments as Map)['title'], '1 B/s\n2 B/s');
  });

  test('offers every outbound mode as a menu entry', () async {
    await update(_trayState(mode: Mode.global));

    final checkedModes = _items(showCall())
        .where((item) => item['checked'] == true)
        .map((item) => item['label'])
        .toList();
    expect(checkedModes, contains(Intl.message(Mode.global.name)));
  });

  test('sends icon, tooltip and menu in a single show call', () async {
    await update(_trayState(isStart: true, tunEnable: true));

    final showCalls = calls.where((call) => call.method == 'show').toList();
    expect(showCalls, hasLength(1));

    final arguments = showCalls.single.arguments as Map;
    expect(arguments['toolTip'], appName);
    expect(arguments['menu'], isNotEmpty);
    final reps = ((arguments['icon'] as Map)['reps'] as List).cast<Map>();
    expect(reps.map((rep) => rep['scale']), containsAll([1.0, 2.0, 3.0, 4.0]));
    expect(reps.map((rep) => rep['bytes']), everyElement(isNotEmpty));
    expect((arguments['icon'] as Map)['isTemplate'], isTrue);
  });

  test('skips the platform call when the tray state is unchanged', () async {
    await update(_trayState(isStart: true));
    await update(_trayState(isStart: true));

    expect(calls.where((call) => call.method == 'show'), hasLength(1));
  });

  test('menu item ids are stable across identical rebuilds', () async {
    await update(_trayState());
    final first = _items(showCall()).map((item) => item['id']).toList();

    Tray.instance.resetForTesting();
    calls.clear();

    await update(_trayState());
    final second = _items(showCall()).map((item) => item['id']).toList();

    expect(second, first);
    expect(first.first, 1024);
  });

  test('group submenus carry their proxies as nested items', () async {
    await update(
      _trayState(
        groups: [
          const Group(
            name: 'Proxy',
            type: GroupType.Selector,
            now: 'A',
            all: [Proxy(name: 'A', type: 'Direct')],
          ),
        ],
      ),
    );

    final submenu = _items(showCall()).firstWhere(
      (item) =>
          item['type'] == 'submenu' &&
          item['label'] != currentAppLocalizations.profile,
    );
    expect(submenu['label'], 'Proxy');
    expect(submenu['sublabel'], 'A');
    expect(submenu['usesCustomView'], isTrue);
    final children = (submenu['items'] as List).cast<Map<Object?, Object?>>();
    expect(children.map((item) => item['label']), contains('A'));
    final delayTest = children.first;
    expect(delayTest['key'], 'delay-test:Proxy');
    expect(delayTest['keepsMenuOpen'], isTrue);
    final proxy = children.firstWhere((item) => item['label'] == 'A');
    expect(proxy['key'], 'delay:Proxy:A');
    expect(proxy['checked'], isTrue);
    expect(proxy['usesCustomView'], isTrue);
  });

  test('large menus read delay state once for all proxy entries', () async {
    final nodes = List.generate(
      2000,
      (i) => Proxy(name: 'node-$i', type: 'ss'),
    );
    final groups = List.generate(
      5,
      (i) => Group(name: 'group-$i', type: GroupType.Selector, all: nodes),
    );
    final reads = <Object, int>{};
    T read<T>(ProviderListenable<T> provider) {
      reads.update(provider, (count) => count + 1, ifAbsent: () => 1);
      return container.read(provider);
    }

    await tray.update(
      trayState: _trayState(groups: groups),
      traffic: const Traffic(),
      read: read,
    );

    expect(reads[delayDataSourceProvider], 1);
    expect(reads[pendingDelayTestsProvider], 1);
    expect(
      reads.values.fold<int>(0, (sum, count) => sum + count),
      lessThan(40),
    );
    final submenus = _items(showCall()).where(
      (item) =>
          item['type'] == 'submenu' &&
          item['label'] != currentAppLocalizations.profile,
    );
    expect(submenus, hasLength(5));
    for (final submenu in submenus) {
      expect(submenu['items'], hasLength(2002));
    }
  });

  test(
    'delay snapshots preserve nested selections, URLs and pending tests',
    () async {
      const nested = Group(
        name: 'nested',
        type: GroupType.Selector,
        now: 'other',
        testUrl: 'https://nested.test',
        all: [Proxy(name: 'chosen', type: 'ss')],
      );
      container.dispose();
      container = ProviderContainer(
        overrides: [
          groupsProvider.overrideWithValue([nested]),
          selectedMapProvider.overrideWithValue({'nested': 'chosen'}),
          appSettingProvider.overrideWithValue(
            const AppSettingProps(testUrl: 'https://default.test'),
          ),
          delayDataSourceProvider.overrideWithValue({
            'https://nested.test': {'chosen': 42, 'other': 999},
            'https://group.test': {'direct': 17, 'slow': -1, 'busy': 99},
            'https://default.test': {'direct': 21},
          }),
          pendingDelayTestsProvider.overrideWithValue({
            delayTestKey('https://group.test', 'busy'),
          }),
        ],
      );

      await update(
        _trayState(
          groups: [
            const Group(
              name: 'group',
              type: GroupType.Selector,
              testUrl: 'https://group.test',
              all: [
                Proxy(name: 'nested', type: 'Selector'),
                Proxy(name: 'direct', type: 'ss'),
                Proxy(name: 'slow', type: 'ss'),
                Proxy(name: 'busy', type: 'ss'),
                Proxy(name: 'unknown', type: 'ss'),
              ],
            ),
            const Group(
              name: 'fallback',
              type: GroupType.Selector,
              all: [Proxy(name: 'direct', type: 'ss')],
            ),
          ],
        ),
      );

      final submenus = _items(showCall()).where(
        (item) =>
            item['type'] == 'submenu' &&
            item['label'] != currentAppLocalizations.profile,
      );
      final entries = (submenus.first['items'] as List).cast<Map>();
      final labels = {
        for (final item in entries) item['label']: item['sublabel'],
      };
      expect(labels['nested'], '42 ms');
      expect(labels['direct'], '17 ms');
      expect(labels['slow'], currentAppLocalizations.timeout);
      expect(labels['busy'], '...');
      expect(labels['unknown'], isNull);
      final fallback = (submenus.last['items'] as List).cast<Map>();
      expect(fallback.last['sublabel'], '21 ms');
    },
  );

  for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
    group(platform.name, () {
      const proxyGroup = Group(
        name: 'Proxy & 自动',
        type: GroupType.Selector,
        now: 'A',
        testUrl: 'https://group.test',
        all: [
          Proxy(name: 'A', type: 'ss'),
          Proxy(name: 'B & 香港', type: 'ss'),
        ],
      );

      setUp(() {
        debugDefaultTargetPlatformOverride = platform;
        tray = AppTray.forPlatform(
          isMacOS: false,
          isWindows: platform == TargetPlatform.windows,
        );
      });

      Map<Object?, Object?> proxySubmenu() => _items(showCall()).singleWhere(
        (item) =>
            item['type'] == 'submenu' &&
            item['label'] != currentAppLocalizations.profile,
      );

      Future<void> select(Map<Object?, Object?> item) async {
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              _channel.name,
              const StandardMethodCodec().encodeMethodCall(
                MethodCall('onMenuItemSelected', {'id': item['id']}),
              ),
              (_) {},
            );
      }

      test('shows proxy groups, current selection and delay results', () async {
        container
            .read(delayDataSourceProvider.notifier)
            .setDelay(
              const Delay(url: 'https://group.test', name: 'B & 香港', value: 42),
            );
        await update(
          _trayState(
            isStart: true,
            groups: [proxyGroup],
            selectedMap: {proxyGroup.name: 'B & 香港'},
          ),
        );

        final arguments = showCall()!.arguments as Map;
        expect((arguments['icon'] as Map)['isTemplate'], isFalse);
        final submenu = proxySubmenu();
        expect(submenu['label'], proxyGroup.name);
        expect(submenu['sublabel'], 'B & 香港');
        expect(submenu['usesCustomView'], isNull);
        final children = (submenu['items'] as List).cast<Map>();
        expect(children.first['label'], currentAppLocalizations.delayTest);
        expect(children.last['label'], 'B & 香港');
        expect(children.last['sublabel'], '42 ms');
        expect(children.last['usesCustomView'], isNull);
        expect(children.last['checked'], isTrue);
        expect(children[2]['checked'], isFalse);
        expect(
          _labels(showCall()),
          isNot(contains(currentAppLocalizations.speedStatistics)),
        );

        await update(_trayState(groups: [proxyGroup]));
        final refreshed = proxySubmenu();
        expect(refreshed['sublabel'], 'A');
        final refreshedChildren = (refreshed['items'] as List).cast<Map>();
        expect(refreshedChildren[2]['checked'], isTrue);
        expect(refreshedChildren.last['checked'], isFalse);
      });

      test(
        'dispatches node selection and updates group delay results',
        () async {
          final action = _TrayProxiesAction();
          container.dispose();
          container = ProviderContainer(
            overrides: [proxiesActionProvider.overrideWith(() => action)],
          );
          await update(_trayState(groups: [proxyGroup]));
          final children = (proxySubmenu()['items'] as List).cast<Map>();

          await select(children.last);
          expect(action.selections, [
            (groupName: proxyGroup.name, proxyName: 'B & 香港'),
          ]);

          final updatesFinished = Completer<void>();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(_channel, (call) async {
                calls.add(call);
                if (call.method == 'updateMenuItems') {
                  final updates = (call.arguments as Map)['updates'] as List;
                  if ((updates.first as Map)['enabled'] == true) {
                    updatesFinished.complete();
                  }
                }
                return true;
              });
          await select(children.first);
          await updatesFinished.future;

          expect(action.testedGroups, [proxyGroup.all]);
          final batches = calls
              .where((call) => call.method == 'updateMenuItems')
              .map((call) => (call.arguments as Map)['updates'] as List)
              .toList();
          expect((batches.first.single as Map)['enabled'], isFalse);
          expect((batches.last.single as Map)['enabled'], isTrue);
          final delays = batches[1].cast<Map>();
          final groupKey = Uri.encodeComponent(proxyGroup.name);
          expect(delays.map((item) => item['key']), [
            for (final proxy in proxyGroup.all)
              'delay:$groupKey:${Uri.encodeComponent(proxy.name)}',
          ]);
          expect(delays.map((item) => item['sublabel']), everyElement('42 ms'));
          expect(
            delays.map((item) => item['sublabelStyle']),
            everyElement('badge'),
          );
        },
      );

      test('shares delay updates by resolved proxy and test URL', () async {
        final action = _TrayProxiesAction();
        final shared = proxyGroup.copyWith(name: 'shared');
        final differentUrl = proxyGroup.copyWith(
          name: 'different',
          testUrl: 'https://different.test',
        );
        final nested = proxyGroup.copyWith(
          name: 'nested',
          all: const [Proxy(name: 'A', type: 'ss')],
        );
        final parent = proxyGroup.copyWith(
          name: 'parent',
          testUrl: 'https://parent.test',
          all: const [Proxy(name: 'nested', type: 'Selector')],
        );
        container.dispose();
        container = ProviderContainer(
          overrides: [
            proxiesActionProvider.overrideWith(() => action),
            groupsProvider.overrideWithValue([nested]),
            selectedMapProvider.overrideWithValue({'nested': 'A'}),
          ],
        );
        await update(
          _trayState(groups: [proxyGroup, shared, differentUrl, parent]),
        );
        final submenu = _items(
          showCall(),
        ).singleWhere((item) => item['label'] == proxyGroup.name);
        final finished = Completer<void>();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_channel, (call) async {
              calls.add(call);
              if (call.method == 'updateMenuItems') {
                final updates = (call.arguments as Map)['updates'] as List;
                if ((updates.first as Map)['enabled'] == true) {
                  finished.complete();
                }
              }
              return true;
            });
        await select((submenu['items'] as List).first as Map<Object?, Object?>);
        await finished.future;
        final updates = calls
            .where((call) => call.method == 'updateMenuItems')
            .expand((call) => (call.arguments as Map)['updates'] as List)
            .cast<Map>()
            .where((item) => item.containsKey('sublabel'));
        expect(updates.map((item) => item['key']), [
          for (final group in [proxyGroup, shared, parent])
            for (final proxy in group.all)
              'delay:${Uri.encodeComponent(group.name)}:${Uri.encodeComponent(proxy.name)}',
        ]);
        expect(updates.map((item) => item['sublabel']), everyElement('42 ms'));
      });

      test('removes proxy submenus when groups become empty', () async {
        await update(_trayState(groups: [proxyGroup]));
        await update(_trayState());

        expect(
          _items(showCall()).where(
            (item) =>
                item['type'] == 'submenu' &&
                item['label'] != currentAppLocalizations.profile,
          ),
          isEmpty,
        );
      });

      test('never pushes a tray title', () async {
        await tray.updateTitle(
          showNetworkSpeed: true,
          isStart: true,
          traffic: const Traffic(),
        );

        expect(calls.where((call) => call.method == 'setTitle'), isEmpty);
      });
    });
  }
}
