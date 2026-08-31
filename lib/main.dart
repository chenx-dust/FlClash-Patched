import 'dart:async';
import 'dart:io';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/pages/error.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust_api/rust_api.dart';

import 'application.dart';
import 'bootstrap.dart';
import 'common/common.dart';
import 'common/window.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        Future.microtask(() {
          commonPrint.log(
            'exception: ${details.exception} stack: ${details.stack}',
            logLevel: LogLevel.warning,
          );
        });
      };
      try {
        await RustLib.init();
        final version = await system.init();
        final container = await bootstrap.init(version);
        if (system.isDesktop && !kDebugMode) {
          final signals = [
            ProcessSignal.sigint,
            if (!system.isWindows) ProcessSignal.sigterm,
          ];
          for (final signal in signals) {
            signal.watch().listen((signal) {
              commonPrint.log('Received process signal: ${signal.name}');
              unawaited(
                container.read(systemActionProvider.notifier).handleExit(),
              );
            });
          }
        }
        HttpOverrides.global = FlClashHttpOverrides(container);
        request.attach(container.read);
        runApp(
          UncontrolledProviderScope(
            container: container,
            child: const Application(),
          ),
        );
      } catch (e, s) {
        commonPrint.log(
          'Failed to initialize: $e, $s',
          logLevel: LogLevel.error,
        );
        runApp(
          MaterialApp(
            home: InitErrorScreen(error: e, stack: s),
          ),
        );
        unawaited(window?.showInitFailure());
      }
    },
    (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    },
  );
}
