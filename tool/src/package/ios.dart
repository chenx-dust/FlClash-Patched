import 'dart:io';

import 'package:fl_clash/common/release_asset.dart';
import 'package:path/path.dart' as p;

import 'context.dart';
import 'steps.dart';

const defaultIosAppBundleId = 'com.follow.clash';
const iosAppOutputPath = 'build/ios/iphoneos/Runner.app';
const iosIpaOutputPath = 'build/ios/ipa';

typedef IosSigningTarget = ({
  String bundle,
  String bundleIdentifier,
  String entitlements,
});

ReleaseArch iosArch(List<ReleaseArch> requested) {
  if (requested.isEmpty ||
      (requested.length == 1 && requested.single == ReleaseArch.arm64)) {
    return ReleaseArch.arm64;
  }
  throw const PackageError('iOS packages only support --arch arm64');
}

List<String> iosFlutterBuildArguments(
  PackageContext context, {
  required bool verbose,
}) {
  return [
    'build',
    'ios',
    '--release',
    '--no-codesign',
    '--dart-define-from-file=env.json',
    '--build-name',
    context.buildName,
    '--build-number',
    context.buildNumber,
    if (verbose) '--verbose',
  ];
}

List<IosSigningTarget> iosSigningTargets({
  required String rootDir,
  required String appPath,
  required String appBundleId,
}) {
  return [
    for (final name in const ['NECore', 'Widget', 'Runner'])
      (
        bundle: name == 'Runner'
            ? appPath
            : p.join(appPath, 'PlugIns', '$name.appex'),
        bundleIdentifier: name == 'Runner' ? appBundleId : '$appBundleId.$name',
        entitlements: p.join(rootDir, 'ios', name, '$name.entitlements'),
      ),
  ];
}

/// Resolves the build settings Xcode would expand. iOS refuses a Network
/// Extension whose signature names no application identifier, so a placeholder
/// team stands in until the bundle is signed for real.
String iosEntitlements({
  required String source,
  required String appBundleId,
  required String bundleIdentifier,
  String? teamIdentifier,
}) {
  final team = teamIdentifier ?? 'UNKNOWN000';
  final resolved = source.replaceAll(r'$(APP_BUNDLE_ID)', appBundleId);
  final end = resolved.lastIndexOf('</dict>');
  if (end < 0) {
    throw const FormatException('Entitlements plist is missing its dictionary');
  }
  return '${resolved.substring(0, end)}'
      '\t<key>application-identifier</key>\n'
      '\t<string>$team.$bundleIdentifier</string>\n'
      '\t<key>com.apple.developer.team-identifier</key>\n'
      '\t<string>$team</string>\n'
      '${resolved.substring(end)}';
}

/// The IPA ships unsigned for whoever installs it to sign; each bundle still
/// carries its own entitlements, since a re-signer copies them from the bundle.
TargetPlan planIpa(PackageContext context) {
  final name = context.assetName(
    ReleaseArch.arm64,
    'ipa',
    form: ReleaseForm.unsigned,
  );
  final output = context.outputPath(name);
  return TargetPlan(
    steps: [
      Task('ad-hoc sign $iosAppOutputPath and archive into $output', () async {
        final appPath = context.path(iosAppOutputPath);
        if (!Directory(appPath).existsSync()) {
          throw PackageError('iOS app bundle not found: $appPath');
        }
        final frameworks = Directory(p.join(appPath, 'Frameworks'));
        if (frameworks.existsSync()) {
          for (final framework in frameworks.listSync()) {
            await _adHocSign(framework.path);
          }
        }
        final stage = context.stagingPath('ipa');
        await recreateDirectory(stage);
        // Inner bundles first: signing the app seals the extensions it embeds.
        for (final target in iosSigningTargets(
          rootDir: context.root,
          appPath: appPath,
          appBundleId: defaultIosAppBundleId,
        )) {
          final entitlements = File(
            p.join(stage, '${p.basename(target.bundle)}.entitlements'),
          );
          entitlements.writeAsStringSync(
            iosEntitlements(
              source: File(target.entitlements).readAsStringSync(),
              appBundleId: defaultIosAppBundleId,
              bundleIdentifier: target.bundleIdentifier,
            ),
          );
          await _adHocSign(target.bundle, entitlements: entitlements.path);
        }
        final payload = p.join(stage, 'Payload');
        await Command('ditto', [
          appPath,
          p.join(payload, 'Runner.app'),
        ]).run(verbose: false);
        final previous = File(output);
        if (previous.existsSync()) previous.deleteSync();
        await Command('ditto', [
          '-c',
          '-k',
          '--sequesterRsrc',
          '--keepParent',
          payload,
          output,
        ]).run(verbose: false);
      }),
    ],
    artifacts: [
      PlannedArtifact(
        name: name,
        arch: ReleaseArch.arm64,
        form: ReleaseForm.unsigned,
      ),
    ],
  );
}

Future<void> _adHocSign(String path, {String? entitlements}) async {
  await Command('codesign', [
    '--force',
    '--sign',
    '-',
    '--timestamp=none',
    if (entitlements != null) ...[
      '--generate-entitlement-der',
      '--entitlements',
      entitlements,
    ],
    path,
  ]).run(verbose: false);
}
