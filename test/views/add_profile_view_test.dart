import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/add.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

ProviderContainer _containerFor(WidgetTester tester) {
  const size = Size(1400, 1000);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  globalState.container = container;
  container.read(viewSizeProvider.notifier).update((_) => size);
  return container;
}

void main() {
  testWidgets('lists new, QR code, file, and URL entries', (tester) async {
    final container = _containerFor(tester);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => AddProfileView(context: context),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = currentAppLocalizations;
    expect(find.text(l10n.newProfile), findsOne);
    expect(find.text(l10n.qrcode), findsOne);
    expect(find.text(l10n.file), findsOne);
    expect(find.text(l10n.url), findsOne);
    expect(tester.takeException(), null);
  });

  testWidgets('new profile requires a name and opens an empty editor', (
    tester,
  ) async {
    final container = _containerFor(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => AddProfileView(context: context),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = currentAppLocalizations;
    await tester.tap(find.text(l10n.newProfile));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text(l10n.submit));
    await tester.pumpAndSettle();
    expect(find.text(l10n.profileNameNullValidationDesc), findsOne);
    expect(find.byType(EditorPage), findsNothing);

    await tester.enterText(find.byType(TextFormField), '  My profile  ');
    await tester.tap(find.text(l10n.submit));
    await tester.pumpAndSettle();
    final editor = tester.widget<EditorPage>(find.byType(EditorPage));
    expect(editor.title, 'My profile');
    expect(editor.content, isEmpty);
    expect(editor.onSave, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new editor uses the profiles navigator and closes the sheet', (
    tester,
  ) async {
    final container = _containerFor(tester);
    final pageNavigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Navigator(
            key: pageNavigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (pageContext) => Scaffold(
                body: TextButton(
                  onPressed: () => showExtend<void>(
                    globalState.navigatorKey.currentContext!,
                    builder: (context) => AdaptiveSheetScaffold(
                      title: currentAppLocalizations.addProfile,
                      body: AddProfileView(
                        context: context,
                        editorContext: pageContext,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(currentAppLocalizations.newProfile));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Local');
    await tester.tap(find.text(currentAppLocalizations.submit));
    await tester.pumpAndSettle();
    expect(find.byType(AddProfileView), findsNothing);
    expect(
      Navigator.of(tester.element(find.byType(EditorPage))),
      same(pageNavigator.currentState),
    );
    expect(globalState.navigatorKey.currentState!.canPop(), isFalse);
    pageNavigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('URL import dialog rejects an empty value and keeps the sheet', (
    tester,
  ) async {
    final container = _containerFor(tester);
    ({String url, String? ageSecretKey})? popped;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  popped =
                      await showDialog<({String url, String? ageSecretKey})>(
                        context: context,
                        builder: (_) => const URLFormDialog(),
                      );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(URLFormDialog), findsOne);

    await tester.tap(find.text(currentAppLocalizations.submit));
    await tester.pumpAndSettle();

    expect(
      find.byType(URLFormDialog),
      findsOne,
      reason: 'an empty URL must not close the dialog',
    );
    expect(popped, isNull);
    expect(tester.takeException(), null);
  });

  testWidgets('URL import dialog returns the entered value', (tester) async {
    final container = _containerFor(tester);
    ({String url, String? ageSecretKey})? popped;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  popped =
                      await showDialog<({String url, String? ageSecretKey})>(
                        context: context,
                        builder: (_) => const URLFormDialog(),
                      );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'https://example.com/profile',
    );
    await tester.tap(find.text(currentAppLocalizations.submit));
    await tester.pumpAndSettle();

    expect(find.byType(URLFormDialog), findsNothing);
    expect(popped?.url, 'https://example.com/profile');
    expect(popped?.ageSecretKey, isNull);
    expect(tester.takeException(), null);
  });

  testWidgets('URL import dialog pastes the clipboard into the URL field', (
    tester,
  ) async {
    final container = _containerFor(tester);
    ({String url, String? ageSecretKey})? popped;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': '  https://example.com/clip  '};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  popped =
                      await showDialog<({String url, String? ageSecretKey})>(
                        context: context,
                        builder: (_) => const URLFormDialog(),
                      );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(currentAppLocalizations.paste));
    await tester.pumpAndSettle();
    await tester.tap(find.text(currentAppLocalizations.submit));
    await tester.pumpAndSettle();

    expect(find.byType(URLFormDialog), findsNothing);
    expect(popped?.url, 'https://example.com/clip');
    expect(popped?.ageSecretKey, isNull);
    expect(tester.takeException(), null);
  });
}
