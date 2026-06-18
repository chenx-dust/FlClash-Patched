import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'error.dart';

final _log = Logger('util');

ProcessResult runCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
}) {
  _log.finer('Running: $executable ${arguments.join(' ')}');
  if (environment != null && environment.isNotEmpty) {
    _log.finer('  env: $environment');
  }
  final result = Process.runSync(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
    stdoutEncoding: systemEncoding,
    stderrEncoding: systemEncoding,
  );
  final out = (result.stdout as String).trim();
  final err = (result.stderr as String).trim();
  if (out.isNotEmpty) _log.finest(out);
  if (err.isNotEmpty) _log.finest(err);
  if (result.exitCode != 0) {
    throw CommandFailedException(
      executable: executable,
      arguments: arguments,
      exitCode: result.exitCode,
      stdout: out,
      stderr: err,
    );
  }
  return result;
}

Future<void> runCommandStream(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async {
  _log.info('exec: $executable ${arguments.join(' ')}');
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: true,
    runInShell: Platform.isWindows,
  );

  final stdout = _collectProcessOutput(
    process.stdout,
    (line) => _log.info(line),
  );
  final stderr = _collectProcessOutput(
    process.stderr,
    (line) => _log.warning(line),
  );

  final exitCode = await process.exitCode;
  final output = await Future.wait([stdout, stderr]);
  if (exitCode != 0) {
    throw CommandFailedException(
      executable: executable,
      arguments: arguments,
      exitCode: exitCode,
      stdout: output[0],
      stderr: output[1],
    );
  }
}

Future<String> _collectProcessOutput(
  Stream<List<int>> stream,
  void Function(String line) logLine,
) async {
  final output = StringBuffer();
  var pendingLine = '';

  await for (final data in stream.transform(systemEncoding.decoder)) {
    output.write(data);

    final text = pendingLine + data;
    final lines = text.split('\n');
    pendingLine = lines.removeLast();

    for (final line in lines) {
      final normalizedLine = line.endsWith('\r')
          ? line.substring(0, line.length - 1)
          : line;
      if (normalizedLine.isNotEmpty) logLine(normalizedLine);
    }
  }

  final tail = pendingLine.endsWith('\r')
      ? pendingLine.substring(0, pendingLine.length - 1)
      : pendingLine;
  if (tail.isNotEmpty) logLine(tail);

  return output.toString().trim();
}

Future<String> calcSha256(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw BuildException('File not found: $filePath');
  }
  final hash = await sha256.bind(file.openRead()).first;
  return hash.toString();
}

void ensureDir(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
}

void copyFile(String source, String destination) {
  final src = File(source);
  if (!src.existsSync()) {
    throw BuildException('Source file not found: $source');
  }
  final dest = File(destination);
  ensureDir(dest.parent.path);
  src.copySync(destination);
  _log.fine('Copied $source -> $destination');
}

String joinPath(String part1,
    [String? part2, String? part3, String? part4]) {
  return p.join(part1, part2, part3, part4);
}
