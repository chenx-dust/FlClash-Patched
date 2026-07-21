import 'package:fl_clash/common/path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final secureToken = RegExp(r'^[A-Za-z0-9_-]{21}[AQgw]$');
  const runtimeToken = 'EREREREREREREREREREREQ';
  const socketToken = 'IiIiIiIiIiIiIiIiIiIiIg';

  test('Unix IPC path uses 128-bit Base64URL tokens', () {
    final runtimeDirectoryName = unixSocketRuntimeDirectory.split('/').last;
    final socketName = unixSocketPath.split('/').last;
    final actualSocketToken = socketName.substring(4, socketName.length - 5);

    expect(unixSocketPath, startsWith('$unixSocketRuntimeDirectory/ipc-'));
    expect(socketName, endsWith('.sock'));
    expect(actualSocketToken, matches(secureToken));
    expect(runtimeDirectoryName, anyOf('flclash', startsWith('flclash-')));
    if (runtimeDirectoryName != 'flclash') {
      expect(
        runtimeDirectoryName.substring('flclash-'.length),
        matches(secureToken),
      );
    }
  });

  test('Linux uses XDG runtime directory when the path fits', () {
    final paths = resolveUnixSocketPaths(
      isLinux: true,
      isMacOS: false,
      environment: const {'XDG_RUNTIME_DIR': '/run/user/1000/'},
      systemTemp: '/ignored',
      runtimeToken: runtimeToken,
      socketToken: socketToken,
    );

    expect(paths.runtimeDirectory, '/run/user/1000/flclash');
    expect(paths.socketPath, '/run/user/1000/flclash/ipc-$socketToken.sock');
  });

  test('Linux falls back to a randomized directory under tmp', () {
    final paths = resolveUnixSocketPaths(
      isLinux: true,
      isMacOS: false,
      environment: const {},
      systemTemp: '/ignored',
      runtimeToken: runtimeToken,
      socketToken: socketToken,
    );

    expect(paths.runtimeDirectory, '/tmp/flclash-$runtimeToken');
    expect(
      paths.socketPath,
      '/tmp/flclash-$runtimeToken/ipc-$socketToken.sock',
    );
  });

  test('macOS uses its per-user temporary directory', () {
    final paths = resolveUnixSocketPaths(
      isLinux: false,
      isMacOS: true,
      environment: const {},
      systemTemp: '/var/folders/user/T/',
      runtimeToken: runtimeToken,
      socketToken: socketToken,
    );

    expect(paths.runtimeDirectory, '/var/folders/user/T/flclash');
    expect(
      paths.socketPath,
      '/var/folders/user/T/flclash/ipc-$socketToken.sock',
    );
  });

  test('overlong preferred path falls back to tmp', () {
    final longPathComponent = List.filled(80, 'a').join();
    final paths = resolveUnixSocketPaths(
      isLinux: false,
      isMacOS: true,
      environment: const {},
      systemTemp: '/var/folders/$longPathComponent/T',
      runtimeToken: runtimeToken,
      socketToken: socketToken,
    );

    expect(paths.runtimeDirectory, '/tmp/flclash-$runtimeToken');
    expect(
      paths.socketPath,
      '/tmp/flclash-$runtimeToken/ipc-$socketToken.sock',
    );
  });

  test('Windows pipe name uses a 128-bit Base64URL token', () {
    const prefix = r'\\.\pipe\FlClashCore_';
    final pipeToken = windowsPipeName.substring(prefix.length);

    expect(windowsPipeName, startsWith(prefix));
    expect(pipeToken, matches(secureToken));
  });
}
