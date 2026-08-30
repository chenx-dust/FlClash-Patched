import 'dart:io';

import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/common/app_ports.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/provider_reader.dart';
import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:riverpod/misc.dart' show ProviderListenable;
import 'package:riverpod/riverpod.dart';
import 'package:tray/tray.dart';

const _channel = MethodChannel('tray');

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
  bool showTrayTitle = false,
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
    showTrayTitle: showTrayTitle,
    brightness: Brightness.light,
  );
}

List<Map<Object?, Object?>> _items(MethodCall? call) {
  final menu = (call?.arguments as Map?)?['menu'] as List?;
  return menu?.cast<Map<Object?, Object?>>() ?? const [];
}

List<String> _labels(MethodCall? call) {
  return _items(call).map((item) => item['label']).whereType<String>().toList();
}

Map<Object?, Object?> _submenu(MethodCall? call, String label) {
  return _items(
    call,
  ).firstWhere((item) => item['type'] == 'submenu' && item['label'] == label);
}

List<Map<Object?, Object?>> _submenuItems(Map<Object?, Object?> submenu) {
  return (submenu['items'] as List).cast<Map<Object?, Object?>>();
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

  Future<void> update(
    TrayState trayState, {
    AppTray? on,
    ProviderReader? read,
  }) {
    return (on ?? tray).update(
      trayState: trayState,
      traffic: const Traffic(),
      read: read ?? container.read,
    );
  }

  void useGroupSelectionSource({
    required List<Group> groups,
    Map<String, String> selectedMap = const {},
  }) {
    container.dispose();
    container = ProviderContainer(
      overrides: [
        groupsProvider.overrideWithValue(groups),
        selectedMapProvider.overrideWithValue(selectedMap),
      ],
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

  test('builds the stopped menu without the running-only toggles', () async {
    await update(_trayState());

    final labels = _labels(showCall());
    final l10n = currentAppLocalizations;
    expect(labels, contains(l10n.show));
    expect(labels, contains(l10n.start));
    expect(labels, contains(l10n.autoLaunch));
    expect(labels, contains(l10n.copyEnvVar));
    expect(labels, contains(l10n.exit));
    expect(labels, isNot(contains(l10n.tun)));
    expect(labels, isNot(contains(l10n.systemProxy)));
    final showItem = _items(
      showCall(),
    ).firstWhere((item) => item['label'] == l10n.show);
    expect(showItem['activatesWindow'], isTrue);
  });

  test('adds TUN and system proxy toggles once the core is running', () async {
    await update(_trayState(isStart: true));

    final labels = _labels(showCall());
    final l10n = currentAppLocalizations;
    expect(labels, contains(l10n.stop), reason: 'start flips to stop');
    expect(labels, contains(l10n.tun));
    expect(labels, contains(l10n.systemProxy));
    final startItem = _items(
      showCall(),
    ).firstWhere((item) => item['label'] == l10n.stop);
    expect(startItem['checked'], isTrue);
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
    expect((arguments['icon'] as Map)['bytes'], isNotEmpty);
    expect((arguments['icon'] as Map)['isTemplate'], isTrue);
    expect(arguments['brightness'], 'light');
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
    useGroupSelectionSource(
      groups: [
        const Group(
          name: 'Proxy',
          type: GroupType.Selector,
          now: 'A',
          all: [Proxy(name: 'A', type: 'Direct')],
        ),
      ],
      selectedMap: const {'Proxy': 'A'},
    );
    await update(
      _trayState(
        groups: [
          const Group(
            name: 'Proxy',
            type: GroupType.Selector,
            all: [Proxy(name: 'A', type: 'Direct')],
          ),
        ],
        selectedMap: const {'Proxy': 'A'},
      ),
    );

    final submenu = _items(
      showCall(),
    ).firstWhere((item) => item['type'] == 'submenu');
    expect(submenu['label'], 'Proxy');
    expect(submenu['sublabel'], 'A');
    expect(submenu['sublabelStyle'], 'secondary');
    expect(submenu['usesCustomView'], isTrue);
    final children = (submenu['items'] as List).cast<Map<Object?, Object?>>();
    expect(children.first['label'], currentAppLocalizations.delayTest);
    expect(children.first['key'], 'delay-test:Proxy');
    expect(children.first['keepsMenuOpen'], isTrue);
    expect(children.map((item) => item['label']), contains('A'));
    final proxy = children.firstWhere((item) => item['label'] == 'A');
    expect(proxy['key'], 'delay:Proxy:A');
    expect(proxy['usesCustomView'], isTrue);
  });

  test('selector falls back to Core now for its label and checkmark', () async {
    const proxies = [
      Proxy(name: 'A', type: 'Direct'),
      Proxy(name: 'B', type: 'Direct'),
    ];
    useGroupSelectionSource(
      groups: [
        const Group(
          name: 'Proxy',
          type: GroupType.Selector,
          now: 'A',
          all: proxies,
        ),
      ],
    );

    await update(
      _trayState(
        groups: [
          const Group(
            name: 'Proxy',
            type: GroupType.Selector,
            now: 'A',
            all: proxies,
          ),
        ],
      ),
    );

    final submenu = _submenu(showCall(), 'Proxy');
    final proxiesItems = _submenuItems(
      submenu,
    ).where((item) => item['type'] == 'checkbox').toList();
    expect(submenu['sublabel'], 'A');
    expect(
      proxiesItems.where((item) => item['checked'] == true).single['label'],
      'A',
    );
  });

  test('selector explicit selection takes priority over Core now', () async {
    const proxies = [
      Proxy(name: 'A', type: 'Direct'),
      Proxy(name: 'B', type: 'Direct'),
    ];
    useGroupSelectionSource(
      groups: [
        const Group(
          name: 'Proxy',
          type: GroupType.Selector,
          now: 'A',
          all: proxies,
        ),
      ],
      selectedMap: const {'Proxy': 'B'},
    );

    await update(
      _trayState(
        groups: [
          const Group(
            name: 'Proxy',
            type: GroupType.Selector,
            now: 'A',
            all: proxies,
          ),
        ],
        selectedMap: const {'Proxy': 'B'},
      ),
    );

    final submenu = _submenu(showCall(), 'Proxy');
    final proxiesItems = _submenuItems(
      submenu,
    ).where((item) => item['type'] == 'checkbox').toList();
    expect(submenu['sublabel'], 'B');
    expect(
      proxiesItems.where((item) => item['checked'] == true).single['label'],
      'B',
    );
  });

  test('computed groups keep Core now despite explicit selections', () async {
    const proxies = [
      Proxy(name: 'A', type: 'Direct'),
      Proxy(name: 'B', type: 'Direct'),
    ];
    const sourceGroups = [
      Group(name: 'URL', type: GroupType.URLTest, now: 'A', all: proxies),
      Group(name: 'Fallback', type: GroupType.Fallback, now: 'A', all: proxies),
    ];
    useGroupSelectionSource(
      groups: sourceGroups,
      selectedMap: const {'URL': 'B', 'Fallback': 'B'},
    );

    await update(
      _trayState(
        groups: [
          const Group(
            name: 'URL',
            type: GroupType.URLTest,
            now: 'A',
            all: proxies,
          ),
          const Group(
            name: 'Fallback',
            type: GroupType.Fallback,
            now: 'A',
            all: proxies,
          ),
        ],
        selectedMap: const {'URL': 'B', 'Fallback': 'B'},
      ),
    );

    for (final groupName in ['URL', 'Fallback']) {
      final submenu = _submenu(showCall(), groupName);
      final proxiesItems = _submenuItems(
        submenu,
      ).where((item) => item['type'] == 'checkbox').toList();
      expect(submenu['sublabel'], 'A');
      expect(
        proxiesItems.where((item) => item['checked'] == true).single['label'],
        'A',
      );
    }
  });

  test('group without a selection has no label or checked child', () async {
    const proxies = [
      Proxy(name: 'A', type: 'Direct'),
      Proxy(name: 'B', type: 'Direct'),
    ];
    useGroupSelectionSource(
      groups: [
        const Group(name: 'Proxy', type: GroupType.Selector, all: proxies),
      ],
    );

    await update(
      _trayState(
        groups: [
          const Group(name: 'Proxy', type: GroupType.Selector, all: proxies),
        ],
      ),
    );

    final submenu = _submenu(showCall(), 'Proxy');
    final proxiesItems = _submenuItems(
      submenu,
    ).where((item) => item['type'] == 'checkbox').toList();
    expect(submenu, isNot(contains('sublabel')));
    expect(proxiesItems, everyElement(isNot(containsPair('checked', true))));
  });

  test(
    'nested selector shows and checks its directly selected group',
    () async {
      const nested = Proxy(name: 'Auto', type: 'URLTest');
      useGroupSelectionSource(
        groups: const [
          Group(
            name: 'Proxy',
            type: GroupType.Selector,
            now: 'Auto',
            all: [nested],
          ),
          Group(
            name: 'Auto',
            type: GroupType.URLTest,
            now: 'A',
            all: [Proxy(name: 'A', type: 'Direct')],
          ),
        ],
      );

      await update(
        _trayState(
          groups: const [
            Group(
              name: 'Proxy',
              type: GroupType.Selector,
              now: 'Auto',
              all: [nested],
            ),
          ],
        ),
      );

      final submenu = _submenu(showCall(), 'Proxy');
      final nestedItem = _submenuItems(
        submenu,
      ).singleWhere((item) => item['type'] == 'checkbox');
      expect(submenu['sublabel'], 'Auto');
      expect(nestedItem['label'], 'Auto');
      expect(nestedItem['checked'], isTrue);
    },
  );

  test(
    'filtered selected proxy remains the label without a checkmark',
    () async {
      const visible = Proxy(name: 'Visible', type: 'Direct');
      const hidden = Proxy(name: 'Hidden', type: 'Direct');
      useGroupSelectionSource(
        groups: const [
          Group(
            name: 'Proxy',
            type: GroupType.Selector,
            now: 'Hidden',
            all: [visible, hidden],
          ),
        ],
      );

      await update(
        _trayState(
          groups: const [
            Group(
              name: 'Proxy',
              type: GroupType.Selector,
              now: 'Hidden',
              all: [visible],
            ),
          ],
        ),
      );

      final submenu = _submenu(showCall(), 'Proxy');
      final proxyItems = _submenuItems(
        submenu,
      ).where((item) => item['type'] == 'checkbox');
      expect(submenu['sublabel'], 'Hidden');
      expect(proxyItems, everyElement(containsPair('checked', false)));
    },
  );

  test('does not re-read group selection while building its submenu', () async {
    const proxies = [
      Proxy(name: 'A', type: 'Direct'),
      Proxy(name: 'B', type: 'Direct'),
    ];
    useGroupSelectionSource(
      groups: const [
        Group(name: 'Proxy', type: GroupType.Selector, now: 'A', all: proxies),
      ],
    );
    var selectionReads = 0;
    final Object selectionProvider = selectedProxyNameProvider('Proxy');

    T countingRead<T>(ProviderListenable<T> provider) {
      final Object candidate = provider;
      if (candidate == selectionProvider) {
        selectionReads++;
      }
      return container.read(provider);
    }

    await update(
      _trayState(
        groups: const [
          Group(
            name: 'Proxy',
            type: GroupType.Selector,
            now: 'A',
            all: proxies,
          ),
        ],
      ),
      read: countingRead,
    );

    expect(selectionReads, 0);
  });

  test('clears the macOS tray title when the core stops', () async {
    await update(_trayState(isStart: true));
    await Tray.instance.setTitle('1 KB/s');
    calls.clear();

    await tray.updateTitle(
      showTrayTitle: true,
      isStart: false,
      traffic: const Traffic(),
    );

    final titleCalls = calls
        .where((call) => call.method == 'setTitle')
        .toList();
    expect(titleCalls, hasLength(1));
    expect((titleCalls.single.arguments as Map)['title'], '');
  });

  group('a platform that is not macOS', () {
    late AppTray windows;

    setUp(() {
      windows = AppTray.forPlatform(isMacOS: false, isWindows: true);
    });

    test('gets a plain icon, no group submenus and no speed toggle', () async {
      await update(
        _trayState(
          isStart: true,
          groups: [
            const Group(
              name: 'Proxy',
              type: GroupType.Selector,
              all: [Proxy(name: 'A', type: 'Direct')],
            ),
          ],
        ),
        on: windows,
      );

      final arguments = showCall()!.arguments as Map;
      expect((arguments['icon'] as Map)['isTemplate'], isFalse);
      expect(
        _items(showCall()).where((item) => item['type'] == 'submenu'),
        isEmpty,
      );
      expect(
        _labels(showCall()),
        isNot(contains(currentAppLocalizations.speedStatistics)),
      );
    });

    test('never pushes a tray title', () async {
      await windows.updateTitle(
        showTrayTitle: true,
        isStart: true,
        traffic: const Traffic(),
      );

      expect(calls.where((call) => call.method == 'setTitle'), isEmpty);
    });
  });
}
