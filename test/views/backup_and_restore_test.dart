import 'dart:async';

import 'package:fl_clash/common/exception.dart';
import 'package:fl_clash/common/reset.dart';
import 'package:fl_clash/common/webdav.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/backup_and_restore.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

const _existing = DAVProps(
  uri: 'https://dav.example.com/remote',
  user: 'alice',
  password: 'secret',
  fileName: 'custom.zip',
  directory: '/archives/nightly',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1200, 1400);
    container.listen(davSettingProvider, (_, _) {}, fireImmediately: true);
  });

  tearDown(() => container.dispose());

  Future<void> pumpDialog(WidgetTester tester, Widget dialog) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(child: Scaffold(body: dialog)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openResultDialog(
    WidgetTester tester,
    Widget dialog,
    ValueChanged<String?> onResult,
  ) async {
    await pumpDialog(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            onResult(
              await showDialog<String>(
                context: context,
                builder: (_) => dialog,
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('BackupFileNameDialog', () {
    const dialog = BackupFileNameDialog(
      value: 'backup.zip',
      version: '0.8.92',
      platform: 'android',
    );

    testWidgets(
      'previews substitutions and saves the template with a zip suffix',
      (tester) async {
        String? result;
        await openResultDialog(tester, dialog, (value) => result = value);
        await tester.enterText(
          find.byType(TextFormField),
          'FlClash_{version}_{platform}',
        );
        await tester.pump();
        expect(find.text('FlClash_0.8.92_android.zip'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();
        expect(result, 'FlClash_{version}_{platform}.zip');
      },
    );

    testWidgets('inserts a variable at the current selection', (tester) async {
      await pumpDialog(tester, dialog);
      expect(find.text('Text replacement:'), findsOneWidget);
      final dateRow = find
          .ancestor(
            of: find.text('Local date (YYYY-MM-DD)'),
            matching: find.byType(Row),
          )
          .first;
      expect(
        find.descendant(
          of: dateRow,
          matching: find.text('{date}', findRichText: true),
        ),
        findsOneWidget,
      );
      final controller = tester
          .widget<TextFormField>(find.byType(TextFormField))
          .controller!;
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 6,
      );
      await tester.tap(find.text('{date}', findRichText: true));
      await tester.pump();
      expect(controller.text, '{date}.zip');
      expect(controller.selection.baseOffset, 6);
    });

    testWidgets('rejects unknown variables and path separators', (
      tester,
    ) async {
      await pumpDialog(tester, dialog);
      for (final value in ['{arch}.zip', '../backup.zip', '']) {
        await tester.enterText(find.byType(TextFormField), value);
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();
        expect(find.byType(BackupFileNameDialog), findsOneWidget);
        expect(
          tester.widget<TextFormField>(find.byType(TextFormField)).validator!(
            value,
          ),
          isNotNull,
        );
      }
    });

    testWidgets('reset restores the dynamic default', (tester) async {
      await pumpDialog(tester, dialog);
      await tester.enterText(find.byType(TextFormField), '{time}');
      await tester.tap(find.widgetWithText(TextButton, 'Reset'));
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        defaultDavFileName,
      );
      expect(find.textContaining('FlClash_0.8.92_android_'), findsOneWidget);
    });

    testWidgets('fits a narrow screen with a long template', (tester) async {
      await pumpDialog(tester, dialog);
      tester.view.physicalSize = const Size(360, 800);
      container.read(viewSizeProvider.notifier).value = const Size(360, 800);
      await tester.enterText(
        find.byType(TextFormField),
        'FlClash_{version}_{platform}_{date}_{time}.zip',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancel returns no change and disposes cleanly', (
      tester,
    ) async {
      String? result = 'unchanged';
      await openResultDialog(tester, dialog, (value) => result = value);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('DAVDirectoryBrowserDialog', () {
    testWidgets('directory editor safely disposes while the browser is open', (
      tester,
    ) async {
      container.read(davSettingProvider.notifier).update((_) => _existing);
      await pumpDialog(tester, const BackupAndRestore());
      await tester.tap(find.text('Directory'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Browse'));
      await tester.pumpAndSettle();
      expect(find.byType(DAVDirectoryBrowserDialog), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'enters a folder, returns to the parent and chooses a directory',
      (tester) async {
        String? result;
        await openResultDialog(
          tester,
          DAVDirectoryBrowserDialog(
            directory: '/',
            loadDirectories: (path) async => switch (path) {
              '/' => ['archives'],
              '/archives' => ['nightly'],
              _ => [],
            },
          ),
          (value) => result = value,
        );
        await tester.tap(find.text('archives'));
        await tester.pumpAndSettle();
        expect(find.text('/archives'), findsOneWidget);
        await tester.tap(find.text('Parent directory'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('archives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('nightly'));
        await tester.pumpAndSettle();
        expect(find.text('No subdirectories'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Confirm'));
        await tester.pumpAndSettle();
        expect(result, '/archives/nightly');
      },
    );

    testWidgets(
      'shows errors and retries without selecting a failed directory',
      (tester) async {
        var calls = 0;
        await openResultDialog(
          tester,
          DAVDirectoryBrowserDialog(
            directory: '/',
            loadDirectories: (_) async {
              if (++calls == 1) throw const MessageException('browse failed');
              return ['archives'];
            },
          ),
          (_) {},
        );
        expect(find.text('browse failed'), findsOneWidget);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Confirm'))
              .onPressed,
          isNull,
        );
        await tester.tap(find.widgetWithText(TextButton, 'Retry'));
        await tester.pumpAndSettle();
        expect(find.text('archives'), findsOneWidget);
        expect(calls, 2);
      },
    );

    testWidgets('ignores stale loads and remains safe after disposal', (
      tester,
    ) async {
      final pending = Completer<List<String>>();
      await openResultDialog(
        tester,
        DAVDirectoryBrowserDialog(
          directory: '/archives/nightly',
          loadDirectories: (path) =>
              path == '/archives' ? pending.future : Future.value(['current']),
        ),
        (_) {},
      );
      await tester.tap(find.text('Parent directory'));
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Confirm'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Parent directory'));
      await tester.pumpAndSettle();
      pending.complete(['stale']);
      await tester.pumpAndSettle();
      expect(find.text('/'), findsOneWidget);
      expect(find.text('current'), findsOneWidget);
      expect(find.text('stale'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'browse cancellation preserves the input and submit stores it',
      (tester) async {
        container.read(davSettingProvider.notifier).update((_) => _existing);
        await pumpDialog(tester, const BackupAndRestore());
        await tester.tap(find.text('Directory'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '/chosen');
        expect(
          tester.getTopLeft(find.widgetWithText(TextButton, 'Browse')).dx,
          lessThan(
            tester.getTopLeft(find.widgetWithText(TextButton, 'Submit')).dx,
          ),
        );
        expect(
          find.descendant(
            of: find.byType(TextFormField),
            matching: find.text('Browse'),
          ),
          findsNothing,
        );
        await tester.tap(find.widgetWithText(TextButton, 'Browse'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller!
              .text,
          '/chosen',
        );
        await tester.tap(find.widgetWithText(TextButton, 'Submit'));
        await tester.pumpAndSettle();
        expect(container.read(davSettingProvider)?.directory, '/chosen');
      },
    );
  });

  group('RemoteBackupsDialog', () {
    const dialog = RemoteBackupsDialog(
      files: [
        DAVFile(name: 'latest.zip'),
        DAVFile(name: 'older.zip'),
      ],
    );

    Future<void> confirmDelete(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Confirm').last);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'deletes the selected backup and selects the next remaining one',
      (tester) async {
        final deleted = <String>[];
        String? result;
        await openResultDialog(
          tester,
          RemoteBackupsDialog(
            files: dialog.files,
            onDelete: (name) async => deleted.add(name),
          ),
          (value) => result = value,
        );
        expect(
          tester.getTopLeft(find.widgetWithText(TextButton, 'Delete')).dx,
          lessThan(
            tester.getTopLeft(find.widgetWithText(TextButton, 'Cancel')).dx,
          ),
        );
        await tester.tap(find.text('older.zip'));
        await tester.pump();
        await confirmDelete(tester);
        expect(deleted, ['older.zip']);
        expect(find.text('older.zip'), findsNothing);
        await tester.tap(find.widgetWithText(TextButton, 'Confirm'));
        await tester.pumpAndSettle();
        expect(result, 'latest.zip');
      },
    );

    testWidgets('canceling deletion keeps the backup', (tester) async {
      final deleted = <String>[];
      await openResultDialog(
        tester,
        RemoteBackupsDialog(
          files: dialog.files,
          onDelete: (name) async => deleted.add(name),
        ),
        (_) {},
      );
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(deleted, isEmpty);
      expect(find.text('latest.zip'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('deleting the final backup disables restore and deletion', (
      tester,
    ) async {
      await openResultDialog(
        tester,
        RemoteBackupsDialog(
          files: const [DAVFile(name: 'last.zip')],
          onDelete: (_) async {},
        ),
        (_) {},
      );
      await confirmDelete(tester);
      expect(find.text('No remote backups found'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Confirm'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('failed deletion keeps the file and allows another attempt', (
      tester,
    ) async {
      await openResultDialog(
        tester,
        RemoteBackupsDialog(
          files: dialog.files,
          onDelete: (_) async => throw const MessageException('delete failed'),
        ),
        (_) {},
      );
      await confirmDelete(tester);
      expect(find.text('delete failed'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Confirm').last);
      await tester.pumpAndSettle();
      expect(find.text('latest.zip'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets(
      'pending deletion blocks repeated actions and survives disposal',
      (tester) async {
        final pending = Completer<void>();
        var calls = 0;
        await openResultDialog(
          tester,
          RemoteBackupsDialog(
            files: dialog.files,
            onDelete: (_) {
              calls++;
              return pending.future;
            },
          ),
          (_) {},
        );
        await confirmDelete(tester);
        expect(calls, 1);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Confirm'))
              .onPressed,
          isNull,
        );
        await tester.pumpWidget(const SizedBox());
        pending.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('defaults to the first and latest backup', (tester) async {
      String? result;
      await openResultDialog(tester, dialog, (value) => result = value);
      await tester.tap(find.widgetWithText(TextButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(result, 'latest.zip');
    });

    testWidgets('allows selecting a historical backup', (tester) async {
      String? result;
      await openResultDialog(tester, dialog, (value) => result = value);
      await tester.tap(find.text('older.zip'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(result, 'older.zip');
    });

    testWidgets('cancel downloads nothing', (tester) async {
      String? result = 'unchanged';
      await openResultDialog(tester, dialog, (value) => result = value);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });

  group('RestoreOptionsDialog', () {
    Future<RestoreOption?> openAndChoose(
      WidgetTester tester,
      String label,
    ) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      RestoreOption? chosen;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    chosen = await showDialog<RestoreOption>(
                      context: context,
                      builder: (_) => const RestoreOptionsDialog(),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      return chosen;
    }

    testWidgets('returns onlyProfiles for the config-only option', (
      tester,
    ) async {
      expect(
        await openAndChoose(tester, 'Restore profiles only'),
        RestoreOption.onlyProfiles,
      );
    });

    testWidgets('returns all for the full-data option', (tester) async {
      expect(
        await openAndChoose(tester, 'Restore all data'),
        RestoreOption.all,
      );
    });
  });

  group('ResetDataOptionsDialog', () {
    Future<Set<ResetDataType>?> openAndChoose(
      WidgetTester tester,
      String label,
    ) async {
      Set<ResetDataType>? chosen;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    chosen = await showDialog<Set<ResetDataType>>(
                      context: context,
                      builder: (_) => const ResetDataOptionsDialog(),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final confirm = find.widgetWithText(TextButton, 'Confirm');
      expect(tester.widget<TextButton>(confirm).onPressed, isNull);
      await tester.tap(find.text(label));
      await tester.pump();
      expect(tester.widget<TextButton>(confirm).onPressed, isNotNull);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      return chosen;
    }

    testWidgets('returns one selected data group', (tester) async {
      expect(await openAndChoose(tester, 'Application settings'), {
        ResetDataType.settings,
      });
    });

    testWidgets('returns every reset type for all data', (tester) async {
      expect(await openAndChoose(tester, 'All data'), allResetDataTypes);
    });
  });

  group('WebDAV directory setting', () {
    testWidgets('always offers reset and restores the default directory', (
      tester,
    ) async {
      container
          .read(davSettingProvider.notifier)
          .update((_) => _existing.copyWith(directory: defaultDavDirectory));
      await pumpDialog(tester, const BackupAndRestore());
      await tester.tap(find.text('Directory'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'Reset'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '/custom');
      await tester.tap(find.widgetWithText(TextButton, 'Reset'));
      await tester.pumpAndSettle();
      expect(
        container.read(davSettingProvider)?.directory,
        defaultDavDirectory,
      );
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('stores a custom directory and permits the root', (
      tester,
    ) async {
      container.read(davSettingProvider.notifier).update((_) => _existing);
      await pumpDialog(tester, const BackupAndRestore());
      expect(find.text('/archives/nightly'), findsOneWidget);
      for (final directory in ['backups//daily/', '']) {
        await tester.tap(find.text('Directory'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), directory);
        await tester.tap(find.widgetWithText(TextButton, 'Submit'));
        await tester.pumpAndSettle();
        expect(
          container.read(davSettingProvider)?.directory,
          directory.isEmpty ? '/' : '/backups/daily',
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('rejects traversal and cancel keeps the directory', (
      tester,
    ) async {
      container.read(davSettingProvider.notifier).update((_) => _existing);
      await pumpDialog(tester, const BackupAndRestore());
      await tester.tap(find.text('Directory'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '../backup');
      await tester.tap(find.widgetWithText(TextButton, 'Submit'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);
      expect(
        container.read(davSettingProvider)?.directory,
        '/archives/nightly',
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(
        container.read(davSettingProvider)?.directory,
        '/archives/nightly',
      );
    });
  });

  group('WebDAVFormDialog', () {
    testWidgets('rejects an empty form and stores nothing', (tester) async {
      await pumpDialog(tester, const WebDAVFormDialog());

      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(container.read(davSettingProvider), isNull);
      expect(find.byType(WebDAVFormDialog), findsOneWidget);
    });

    testWidgets('names the password toggle by what pressing it does', (
      tester,
    ) async {
      await pumpDialog(tester, const WebDAVFormDialog());

      final toggle = find.descendant(
        of: find.widgetWithIcon(TextFormField, Symbols.password),
        matching: find.byType(IconButton),
      );
      expect(tester.widget<IconButton>(toggle).tooltip, 'Show password');

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(tester.widget<IconButton>(toggle).tooltip, 'Hide password');
    });

    testWidgets('rejects a malformed address', (tester) async {
      await pumpDialog(tester, const WebDAVFormDialog());

      await tester.enterText(
        find.widgetWithIcon(TextFormField, Symbols.link),
        'not-a-url',
      );
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Symbols.account_circle),
        'alice',
      );
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Symbols.password),
        'secret',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(container.read(davSettingProvider), isNull);
    });

    testWidgets('stores a valid binding with the default file name', (
      tester,
    ) async {
      await pumpDialog(tester, const WebDAVFormDialog());

      await tester.enterText(
        find.widgetWithIcon(TextFormField, Symbols.link),
        'https://dav.example.com/remote',
      );
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Symbols.account_circle),
        'alice',
      );
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Symbols.password),
        'secret',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      final dav = container.read(davSettingProvider);
      expect(dav?.uri, 'https://dav.example.com/remote');
      expect(dav?.user, 'alice');
      expect(dav?.password, 'secret');
      expect(dav?.fileName, defaultDavFileName);
    });

    for (final user in ['', 'alice']) {
      testWidgets('stores an empty password with account "$user"', (
        tester,
      ) async {
        await pumpDialog(tester, const WebDAVFormDialog());

        await tester.enterText(
          find.widgetWithIcon(TextFormField, Symbols.link),
          'https://dav.example.com/remote',
        );
        await tester.enterText(
          find.widgetWithIcon(TextFormField, Symbols.account_circle),
          user,
        );
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();

        final dav = container.read(davSettingProvider);
        expect(dav?.uri, 'https://dav.example.com/remote');
        expect(dav?.user, user);
        expect(dav?.password, '');
        expect(dav?.fileName, defaultDavFileName);
        expect(find.byType(WebDAVFormDialog), findsNothing);
      });
    }

    testWidgets('editing preserves the previously chosen file name', (
      tester,
    ) async {
      container.read(davSettingProvider.notifier).update((_) => _existing);
      await pumpDialog(tester, const WebDAVFormDialog(dav: _existing));

      await tester.enterText(
        find.widgetWithIcon(TextFormField, Symbols.account_circle),
        'bob',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      final dav = container.read(davSettingProvider);
      expect(dav?.user, 'bob');
      expect(dav?.fileName, 'custom.zip');
      expect(dav?.directory, '/archives/nightly');
    });

    testWidgets('offers delete only when editing an existing binding', (
      tester,
    ) async {
      await pumpDialog(tester, const WebDAVFormDialog());
      expect(find.widgetWithText(TextButton, 'Delete'), findsNothing);

      await pumpDialog(tester, const WebDAVFormDialog(dav: _existing));
      expect(find.widgetWithText(TextButton, 'Delete'), findsOneWidget);
    });

    testWidgets('delete clears the stored binding', (tester) async {
      container.read(davSettingProvider.notifier).update((_) => _existing);
      await pumpDialog(tester, const WebDAVFormDialog(dav: _existing));

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(container.read(davSettingProvider), isNull);
    });

    testWidgets('toggles password visibility', (tester) async {
      await pumpDialog(tester, const WebDAVFormDialog(dav: _existing));

      expect(find.byIcon(Symbols.visibility), findsOneWidget);
      await tester.tap(find.byIcon(Symbols.visibility));
      await tester.pumpAndSettle();
      expect(find.byIcon(Symbols.visibility_off), findsOneWidget);
    });
  });
}
