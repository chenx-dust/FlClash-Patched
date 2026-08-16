import 'dart:async';
import 'dart:io';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/config.dart';
import 'package:fl_clash/pages/error.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust_api/rust_api.dart';

import 'application.dart';
import 'common/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (system.isDesktop) {
      await RustLib.init();
    }
    final version = await system.init();
    final container = await globalState.init(version);
    if (system.isDesktop && !kDebugMode) {
      final signals = [
        ProcessSignal.sigint,
        if (!system.isWindows) ProcessSignal.sigterm,
      ];
      for (final signal in signals) {
        signal.watch().listen((signal) {
          commonPrint.log('Received process signal: ${signal.name}');
          unawaited(container.read(systemActionProvider.notifier).handleExit());
        });
      }
    }
    HttpOverrides.global = FlClashHttpOverrides();
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const Application(),
      ),
    );
  } catch (e, s) {
    commonPrint.log(
      'Failed to initialize: '
      '$e, $s',
      logLevel: LogLevel.error,
    );
    await window?.init(0, const WindowProps());
    await window?.show();
    runApp(
      MaterialApp(
        home: InitErrorScreen(error: e, stack: s),
      ),
    );
  }
}
