import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/edit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  final String root;

  _FakePathProvider(this.root);

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => root;
}

/// The edit page disposes the profile by scheduling an auto-apply; keep that a
/// no-op so the setup machinery never runs in a widget test.
class _NoopSetupAction extends SetupAction {
  @override
  void autoApplyProfile() {}
}

Profile _urlProfile() =>
    Profile.normal(label: 'test', url: 'https://example.com/sub');

/// Pumps [EditProfileView] inside a page route (as `showExtend` does), with an
/// outside focus node so escape behavior can be asserted.
Future<FocusNode> pumpEditProfile(
  WidgetTester tester, {
  Profile? profile,
}) async {
  tester.view.physicalSize = const Size(900, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [setupActionProvider.overrideWith(() => _NoopSetupAction())],
  );
  addTearDown(container.dispose);
  // Unmount the widget tree before the container is disposed so State.dispose
  // (which reads a provider) runs against a live container. Teardowns run LIFO,
  // so this must be registered after `container.dispose`.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
  });
  globalState.container = container;

  final outsideFocus = FocusNode();
  addTearDown(outsideFocus.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        builder: (context, child) {
          globalState.measure = Measure.of(context, 1);
          globalState.theme = CommonTheme.of(context, 1);
          return child!;
        },
        home: Scaffold(
          body: Column(
            children: [
              Focus(focusNode: outsideFocus, child: const SizedBox()),
              Expanded(
                child: Navigator(
                  pages: [
                    MaterialPage(
                      child: Builder(
                        builder: (context) => Scaffold(
                          body: EditProfileView(
                            context: context,
                            profile: profile ?? _urlProfile(),
                          ),
                        ),
                      ),
                    ),
                  ],
                  onDidRemovePage: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();

  outsideFocus.requestFocus();
  await tester.pump();
  return outsideFocus;
}

bool _isFabFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context?.findAncestorWidgetOfExactType<FloatingActionButton>() != null;
}

bool _isTextFieldFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context?.findAncestorWidgetOfExactType<EditableText>() != null;
}

bool _isSwitchFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context?.findAncestorWidgetOfExactType<Switch>() != null;
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('edit_profile_focus_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDownAll(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('tabbing into the edit page focuses the Save FAB first', (
    tester,
  ) async {
    final outsideFocus = await pumpEditProfile(tester);
    expect(FocusManager.instance.primaryFocus, outsideFocus);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(
      _isFabFocused(),
      isTrue,
      reason:
          'the Save FAB should be the first focusable target in the edit page, '
          'actual: ${FocusManager.instance.primaryFocus}',
    );
  });

  testWidgets('tabbing reaches every form control after the Save FAB', (
    tester,
  ) async {
    await pumpEditProfile(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_isFabFocused(), isTrue, reason: 'first tab reaches the Save FAB');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      _isTextFieldFocused(),
      isTrue,
      reason: 'tab 2 should reach the name field',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      _isTextFieldFocused(),
      isTrue,
      reason: 'tab 3 should reach the URL field',
    );

    // Fork-specific fields may add focusable inputs before the auto-update
    // toggle. Keep tabbing until the switch itself is reached.
    for (var i = 0; i < 8 && !_isSwitchFocused(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(
      _isTextFieldFocused(),
      isFalse,
      reason:
          'focus should have left the text fields and reached the toggle, '
          'actual: ${FocusManager.instance.primaryFocus}',
    );
    expect(
      _isSwitchFocused(),
      isTrue,
      reason: 'the auto-update Switch is reachable',
    );
  });

  testWidgets('tabbing past the last control escapes to the enclosing scope', (
    tester,
  ) async {
    final outsideFocus = await pumpEditProfile(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_isFabFocused(), isTrue);

    var escaped = false;
    for (var i = 0; i < 30 && !escaped; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      escaped = FocusManager.instance.primaryFocus == outsideFocus;
    }
    expect(
      escaped,
      isTrue,
      reason:
          'tabbing past the last form control should escape to the enclosing '
          'scope, actual: ${FocusManager.instance.primaryFocus}',
    );
  });
}
