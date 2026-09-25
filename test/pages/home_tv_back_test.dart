import 'package:fl_clash/common/system.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/focus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('TV back releases a focused field before moving navigation', (
    tester,
  ) async {
    final harness = await _pumpHome(
      tester,
      deviceTv: true,
      page: _page(PageLabel.dashboard, field: true),
    );

    expect(_editableFocused(), isTrue);

    await _back(tester);

    expect(_editableFocused(), isFalse);
    expect(harness.page, PageLabel.dashboard);
    expect(harness.closeCount, 0);
    expect(_focusedDestination(), isNull);
  });

  testWidgets('TV back releases a focused slider', (tester) async {
    final harness = await _pumpHome(
      tester,
      deviceTv: true,
      page: _page(PageLabel.dashboard, slider: true),
    );

    expect(_editableFocused(), isTrue);

    await _back(tester);

    expect(_editableFocused(), isFalse);
    expect(harness.page, PageLabel.dashboard);
    expect(harness.closeCount, 0);
  });

  testWidgets('TV back moves page focus onto the current destination', (
    tester,
  ) async {
    final harness = await _pumpHome(
      tester,
      deviceTv: true,
      page: _page(PageLabel.dashboard),
    );
    _requestFocus(tester, find.text('content:dashboard'));
    await tester.pump();

    await _back(tester);

    expect(_focusedDestination(), PageLabel.dashboard);
    expect(harness.page, PageLabel.dashboard);
    expect(harness.closeCount, 0);
  });

  testWidgets('TV back returns to the dashboard once navigation has focus', (
    tester,
  ) async {
    final harness = await _pumpHome(
      tester,
      deviceTv: true,
      initialPage: PageLabel.tools,
      page: _page(PageLabel.tools),
    );
    _requestFocus(tester, find.text('content:tools'));
    await tester.pump();

    await _back(tester);

    expect(harness.page, PageLabel.tools);
    expect(_focusedDestination(), PageLabel.tools);
    expect(harness.closeCount, 0);

    await _back(tester);

    expect(harness.page, PageLabel.dashboard);
    expect(_focusedDestination(), PageLabel.dashboard);
    expect(harness.closeCount, 0);
  });

  testWidgets('TV back from the dashboard destination closes the app', (
    tester,
  ) async {
    final harness = await _pumpHome(
      tester,
      deviceTv: true,
      page: _page(PageLabel.dashboard),
    );
    _requestFocus(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.space_dashboard),
      ),
    );
    await tester.pump();
    expect(_focusedDestination(), PageLabel.dashboard);

    await _back(tester);

    expect(harness.closeCount, 1);
    expect(harness.page, PageLabel.dashboard);
  });

  testWidgets('TV mode makes home back release input on a non-TV device', (
    tester,
  ) async {
    final harness = await _pumpHome(
      tester,
      page: _page(PageLabel.dashboard, field: true),
    );
    expect(system.isTV, isFalse);
    expect(_editableFocused(), isTrue);

    harness.container.read(appSettingProvider.notifier).value =
        const AppSettingProps(tvMode: true);
    await tester.pump();

    expect(system.isTV, isFalse);

    await _back(tester);

    expect(_editableFocused(), isFalse);
    expect(harness.page, PageLabel.dashboard);
    expect(harness.closeCount, 0);
  });
}

NavigationItem _page(
  PageLabel label, {
  bool field = false,
  bool slider = false,
}) {
  return NavigationItem(
    icon: Icon(_iconFor(label)),
    label: label,
    builder: (_) => Column(
      children: [
        Text('page:${label.name}'),
        if (field) const TextField(autofocus: true),
        if (slider)
          const Slider(autofocus: true, value: 0.4, onChanged: _ignoreSlider),
        TextButton(onPressed: _noop, child: Text('content:${label.name}')),
      ],
    ),
  );
}

IconData _iconFor(PageLabel label) {
  return switch (label) {
    PageLabel.dashboard => Icons.space_dashboard,
    PageLabel.tools => Icons.construction,
    _ => Icons.circle,
  };
}

class _Harness {
  late final ProviderContainer container;
  var closeCount = 0;

  PageLabel get page => container.read(currentPageLabelProvider);
}

class _CountingSystemAction extends SystemAction {
  _CountingSystemAction(this.onClose);

  final void Function() onClose;

  @override
  void build() {}

  @override
  Future<void> handleClose([bool exit = true]) async {
    onClose();
  }
}

Future<_Harness> _pumpHome(
  WidgetTester tester, {
  bool deviceTv = false,
  PageLabel initialPage = PageLabel.dashboard,
  required NavigationItem page,
}) async {
  system.isTV = deviceTv;
  addTearDown(() {
    system.isTV = false;
  });
  tester.view.physicalSize = const Size(500, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final harness = _Harness();
  harness.container = ProviderContainer(
    overrides: [
      navigationItemsStateProvider.overrideWithValue(
        NavigationItemsState(
          value: [
            page.label == PageLabel.dashboard
                ? page
                : _page(PageLabel.dashboard),
            page.label == PageLabel.tools ? page : _page(PageLabel.tools),
          ],
        ),
      ),
      systemActionProvider.overrideWith(
        () => _CountingSystemAction(() => harness.closeCount++),
      ),
    ],
  );
  addTearDown(harness.container.dispose);
  globalState.container = harness.container;
  harness.container.read(viewSizeProvider.notifier).value = const Size(
    500,
    800,
  );
  if (initialPage != PageLabel.dashboard) {
    harness.container
        .read(currentPageLabelProvider.notifier)
        .toPage(initialPage);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: const TestApp(includeNavigatorKey: false, child: HomePage()),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(NavigationBar), findsOneWidget);
  return harness;
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void _requestFocus(WidgetTester tester, Finder finder) {
  Focus.of(tester.element(finder)).requestFocus();
}

bool _editableFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) {
    return false;
  }
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null ||
      context.widget is Slider ||
      context.findAncestorWidgetOfExactType<Slider>() != null;
}

PageLabel? _focusedDestination() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) {
    return null;
  }
  final ancestor = context
      .findAncestorWidgetOfExactType<NavDestinationAnchor>();
  if (ancestor != null) {
    return ancestor.label;
  }
  NavDestinationAnchor? descendant;
  void visit(Element element) {
    if (descendant != null) {
      return;
    }
    final widget = element.widget;
    if (widget is NavDestinationAnchor) {
      descendant = widget;
      return;
    }
    element.visitChildren(visit);
  }

  context.visitChildElements(visit);
  return descendant?.label;
}

void _noop() {}

void _ignoreSlider(double value) {}
