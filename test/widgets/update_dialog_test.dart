import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/app_update.dart';
import 'package:fl_clash/common/dialog.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/update_progress.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/test_app.dart';

const _runningVersion = '0.8.95';

const _payload =
    '{"schemaVersion":2,"versions":[{"version":"0.8.96","tag":"v0.8.96",'
    '"date":"2026-08-16","prerelease":false,"groups":['
    '{"type":"breaking","entries":[{"id":"af20769","text":'
    '"Re-import backups"}]},'
    '{"type":"feat","entries":[{"id":"1a2b3c4","text":'
    '"Override scripts"}]}]}]}';

const _bulletsOnly =
    '<!-- flclash:changelog:begin -->\n'
    '- Override scripts\n'
    '<!-- flclash:changelog:end -->\n';

String _bodyWith(String payload) =>
    '$_bulletsOnly\n<!-- flclash:changelog:json\n$payload\n-->\n';

ReleaseManifest release(String body, {List<ReleaseAsset> assets = const []}) =>
    ReleaseManifest(tag: 'v0.8.96', notes: body, assets: assets);

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Locale? locale,
  UpdateTarget target = UpdateTarget.unsupported,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  globalState.container = container;
  container
      .read(commonActionProvider.notifier)
      .detectAppUpdateTarget = () async =>
      target;
  // appSettingProvider is autoDispose; in the app `configProvider` keeps it
  // alive, so the test has to hold a listener or edits are dropped.
  container.listen(appSettingProvider, (_, _) {}, fireImmediately: true);
  container
      .read(viewSizeProvider.notifier)
      .update((_) => const Size(1200, 800));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TestApp(
        locale: locale,
        child: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
  await tester.pump();
  return container;
}

/// The dialog blocks until the user answers, so tests must close it before
/// awaiting the call that opened it.
Future<void> tapCancel(WidgetTester tester) async {
  final buttons = find.byType(TextButton);
  await tester.tap(buttons.at(buttons.evaluate().length - 2));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    globalState.packageInfo = PackageInfo(
      appName: 'FlClash',
      packageName: 'cc.chenx.flclash',
      version: _runningVersion,
      buildNumber: '1',
    );
  });

  testWidgets('renders the grouped notes carried by the release', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    final shown = container
        .read(commonActionProvider.notifier)
        .checkUpdateResultHandle(data: release(_bodyWith(_payload)));
    await tester.pumpAndSettle();

    expect(find.textContaining('v0.8.96'), findsOneWidget);
    expect(find.textContaining('Re-import backups'), findsOneWidget);
    expect(find.textContaining('Override scripts'), findsOneWidget);
    expect(find.textContaining('Breaking changes'), findsOneWidget);

    await tapCancel(tester);
    await shown;
  });

  testWidgets('localizes the group titles but not the entries', (tester) async {
    final container = await pumpApp(tester, locale: const Locale('zh', 'CN'));

    final shown = container
        .read(commonActionProvider.notifier)
        .checkUpdateResultHandle(data: release(_bodyWith(_payload)));
    await tester.pumpAndSettle();

    // Entry copy comes from the release payload and is English only; the group
    // headings still follow the app locale.
    expect(find.textContaining('新功能'), findsOneWidget);
    expect(find.textContaining('Override scripts'), findsOneWidget);

    await tapCancel(tester);
    await shown;
  });

  testWidgets('falls back to the bullets of a release without a payload', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    final shown = container
        .read(commonActionProvider.notifier)
        .checkUpdateResultHandle(data: release(_bulletsOnly));
    await tester.pumpAndSettle();

    expect(find.textContaining('- Override scripts'), findsOneWidget);

    await tapCancel(tester);
    await shown;
  });

  testWidgets('stops reminding when an automatic check is dismissed', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    final shown = container
        .read(commonActionProvider.notifier)
        .checkUpdateResultHandle(data: release(_bodyWith(_payload)));
    await tester.pumpAndSettle();
    await tapCancel(tester);
    await shown;

    expect(container.read(appSettingProvider).autoCheckUpdate, isFalse);
  });

  testWidgets('a manual check keeps the setting and reports a failure', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    final shown = container
        .read(commonActionProvider.notifier)
        .checkUpdateResultHandle(isUser: true);
    await tester.pumpAndSettle();

    expect(find.text('Check for updates'), findsOneWidget);

    await tapCancel(tester);
    await shown;
    expect(container.read(appSettingProvider).autoCheckUpdate, isTrue);
  });

  testWidgets('offers an in-place update when the release has the asset', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      target: const UpdateTarget(UpdatePackage.androidApk, 'arm64-v8a'),
    );

    final shown = container
        .read(commonActionProvider.notifier)
        .checkUpdateResultHandle(
          data: release(
            _bodyWith(_payload),
            assets: const [
              ReleaseAsset(
                name: 'FlClash-0.8.96-android-arm64-v8a.apk',
                url: 'https://example.com/a.apk',
                size: 1,
                sha256:
                    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              ),
            ],
          ),
        );
    await tester.pumpAndSettle();

    expect(find.text('Update now'), findsOneWidget);
    expect(find.text('Download'), findsNothing);

    await tapCancel(tester);
    await shown;
  });

  testWidgets('falls back to the release page without a matching asset', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      target: const UpdateTarget(UpdatePackage.androidApk, 'x86_64'),
    );

    final shown = container
        .read(commonActionProvider.notifier)
        .checkUpdateResultHandle(data: release(_bodyWith(_payload)));
    await tester.pumpAndSettle();

    expect(find.text('Download'), findsOneWidget);

    await tapCancel(tester);
    await shown;
  });

  testWidgets('a copy that cannot update itself downloads its own asset', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      target: const UpdateTarget(UpdatePackage.windowsPortable, 'x64'),
    );

    final shown = container
        .read(commonActionProvider.notifier)
        .checkUpdateResultHandle(
          data: release(
            _bodyWith(_payload),
            assets: const [
              ReleaseAsset(
                name: 'FlClash-0.8.96-windows-x64.zip',
                url: 'https://example.com/portable.zip',
                size: 1,
                sha256:
                    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              ),
            ],
          ),
        );
    await tester.pumpAndSettle();

    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Update now'), findsNothing);

    await tapCancel(tester);
    await shown;
  });

  group('UpdateProgressDialog', () {
    testWidgets('update actions fit a narrow window with large text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() async {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.binding.setSurfaceSize(null);
      });
      final container = await pumpApp(tester);
      final shown = container
          .read(commonActionProvider.notifier)
          .checkUpdateResultHandle(data: release(_bulletsOnly));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Open in GitHub'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Open in GitHub')).dy,
        isNot(tester.getCenter(find.text('Download')).dy),
      );
      await tapCancel(tester);
      await shown;
    });

    testWidgets('opens the release page from the update prompt', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return true;
      });
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
      });
      final shown = container
          .read(commonActionProvider.notifier)
          .checkUpdateResultHandle(data: release(_bulletsOnly), isUser: true);
      await tester.pumpAndSettle();

      final open = find.text('Open in GitHub');
      final cancel = find.text('Cancel');
      final confirm = find.text('Download');
      expect(tester.getCenter(open).dx, lessThan(tester.getCenter(cancel).dx));
      expect(tester.getCenter(open).dy, tester.getCenter(cancel).dy);
      expect(
        tester.getCenter(cancel).dx,
        lessThan(tester.getCenter(confirm).dx),
      );
      expect(tester.getCenter(open).dy, tester.getCenter(confirm).dy);
      await tester.tap(open);
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(
        (calls.single.arguments as Map)['url'],
        'https://github.com/chenx-dust/FlClash-Patched/releases/tag/v0.8.96',
      );
      expect(find.text('New version found'), findsOneWidget);

      await tester.tap(cancel);
      await tester.pumpAndSettle();
      await shown;
    });

    Future<ProgressOutcome<int>?> runTask(
      WidgetTester tester,
      ProgressTask<int> task,
    ) async {
      await pumpApp(tester);
      final outcome = dialogs.showCommonDialog<ProgressOutcome<int>>(
        dismissible: false,
        child: UpdateProgressDialog<int>(task: task, expectedTotal: 10),
      );
      await tester.pumpAndSettle();
      return outcome;
    }

    testWidgets('a task finished before the first frame closes cleanly', (
      tester,
    ) async {
      final outcome = await runTask(tester, (_, _) => Future.value(7));

      expect(outcome?.value, 7);
      expect(outcome?.error, isNull);
      expect(find.text('Downloading update'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the dialog is gone before the caller shows the next one', (
      tester,
    ) async {
      await pumpApp(tester);
      Future<void> flow() async {
        await dialogs.showCommonDialog<ProgressOutcome<int>>(
          dismissible: false,
          child: UpdateProgressDialog<int>(
            task: (onProgress, _) async {
              onProgress(5, 10);
              return 1;
            },
          ),
        );
        await dialogs.showMessage(message: const TextSpan(text: 'next step'));
      }

      final shown = flow();
      await tester.pumpAndSettle();

      expect(find.text('next step'), findsOneWidget);
      expect(find.text('Downloading update'), findsNothing);

      await tapCancel(tester);
      await shown;
    });

    testWidgets('cancelling after download discards a verified result', (
      tester,
    ) async {
      await pumpApp(tester);
      final verification = Completer<int>();
      final outcome = dialogs.showCommonDialog<ProgressOutcome<int>>(
        dismissible: false,
        child: UpdateProgressDialog<int>(
          expectedTotal: 10,
          task: (onProgress, _) {
            onProgress(10, 10);
            return verification.future;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      verification.complete(7);
      await tester.pumpAndSettle();

      final result = await outcome;
      expect(result?.value, isNull);
      expect(
        result?.error,
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      );
      expect(find.text('Downloading update'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancel stops the task and reports the cancellation', (
      tester,
    ) async {
      await pumpApp(tester);
      final outcome = dialogs.showCommonDialog<ProgressOutcome<int>>(
        dismissible: false,
        child: UpdateProgressDialog<int>(
          task: (_, cancelToken) async => throw await cancelToken.whenCancel,
        ),
      );
      // The indeterminate bar animates until the task ends, so nothing settles.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        (await outcome)?.error,
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      );
    });
  });
}
