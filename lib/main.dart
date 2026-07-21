import 'dart:async';
import 'dart:io';

import 'package:fl_clash/pages/error.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust_api/rust_api.dart';

import 'application.dart';
import 'common/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (system.isDesktop) {
      await initRustApi();
    }
    final version = await system.version;
    final container = await globalState.init(version);
    if (system.isDesktop) {
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
    runApp(
      MaterialApp(
        home: InitErrorScreen(error: e, stack: s),
      ),
    );
  }
}
