import 'package:path/path.dart' as p;

import 'build.dart';
import 'error.dart';
import 'target.dart';

BuildRequest iosBuildRequest(Map<String, String> environment) {
  if (environment['PLATFORM_NAME'] != 'iphoneos' ||
      environment['ARCHS']?.trim() != 'arm64') {
    throw BuildException('The iOS VPN Core requires an arm64 device build');
  }
  final sourceRoot = environment['SRCROOT'];
  if (sourceRoot == null || sourceRoot.isEmpty) {
    throw BuildException('Xcode must provide SRCROOT for the iOS Core build');
  }
  final rootDir = p.normalize(p.join(sourceRoot, '..'));
  return BuildRequest(
    rootDir: rootDir,
    harnessDir: p.join(rootDir, 'plugins', 'setup', 'setup_hooks'),
    target: Target.iosArm64,
  );
}
