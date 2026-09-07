import 'dart:io';

import 'package:setup_hooks/src/build.dart';
import 'package:setup_hooks/src/ios_build.dart';
import 'package:setup_hooks/src/logging.dart';

Future<void> main() async {
  initLogging();
  try {
    await buildPlatform(iosBuildRequest(Platform.environment));
  } finally {
    closeLogging();
  }
}
