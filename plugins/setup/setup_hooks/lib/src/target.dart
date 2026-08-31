import 'error.dart';

class Target {
  const Target({
    required this.goos,
    required this.goarch,
    this.abi,
    this.lowMemory = false,
  });

  final String goos;
  final String goarch;
  final String? abi;
  final bool lowMemory;

  static const androidArm = Target(
    goos: 'android',
    goarch: 'arm',
    abi: 'armeabi-v7a',
  );
  static const androidArm64 = Target(
    goos: 'android',
    goarch: 'arm64',
    abi: 'arm64-v8a',
  );
  static const androidAmd64 = Target(
    goos: 'android',
    goarch: 'amd64',
    abi: 'x86_64',
  );

  static const iosArm64 = Target(goos: 'ios', goarch: 'arm64', abi: 'arm64');
  static const iosArm64LowMem = Target(
    goos: 'ios',
    goarch: 'arm64',
    abi: 'arm64',
    lowMemory: true,
  );

  static const macosArm64 = Target(goos: 'darwin', goarch: 'arm64');
  static const macosAmd64 = Target(goos: 'darwin', goarch: 'amd64');

  static const linuxArm64 = Target(goos: 'linux', goarch: 'arm64');
  static const linuxAmd64 = Target(goos: 'linux', goarch: 'amd64');

  static const windowsAmd64 = Target(goos: 'windows', goarch: 'amd64');
  static const windowsArm64 = Target(goos: 'windows', goarch: 'arm64');

  static const all = [
    androidArm,
    androidArm64,
    androidAmd64,
    iosArm64,
    iosArm64LowMem,
    macosArm64,
    macosAmd64,
    linuxArm64,
    linuxAmd64,
    windowsAmd64,
    windowsArm64,
  ];

  static List<Target> forPlatform(String platform) =>
      all.where((target) => target.platformDir == platform).toList();

  static Target resolve({required String platform, required String goarch}) {
    for (final target in forPlatform(platform)) {
      if (target.goarch == goarch) return target;
    }
    throw BuildException('No $platform Core target for GOARCH $goarch');
  }

  bool get isLib => abi != null;

  String get dynamicLibExtension => goos == 'ios' ? '.a' : '.so';

  bool get hasHelper => goos == 'linux' || goos == 'windows';

  String get executableExtension => goos == 'windows' ? '.exe' : '';

  String get platformDir => goos == 'darwin' ? 'macos' : goos;

  String get ndkTriple => switch (abi) {
    'armeabi-v7a' => 'armv7a-linux-androideabi',
    'arm64-v8a' => 'aarch64-linux-android',
    'x86_64' => 'x86_64-linux-android',
    _ => throw BuildException('Not an Android target: $this'),
  };

  String get rustTriple {
    final arch = switch (goarch) {
      'amd64' => 'x86_64',
      'arm64' => 'aarch64',
      _ => throw BuildException('No Rust target for $this'),
    };
    return switch (goos) {
      'windows' => '$arch-pc-windows-msvc',
      'linux' => '$arch-unknown-linux-gnu',
      _ => throw BuildException('No Rust target for $this'),
    };
  }

  @override
  String toString() => '$goos/$goarch${abi != null ? ' ($abi)' : ''}';
}
