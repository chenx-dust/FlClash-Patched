import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

final _log = Logger('geodata');

const _geoDataFiles = {
  'GeoIP.metadb':
      'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb',
  'ASN.mmdb':
      'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/GeoLite2-ASN.mmdb',
  'GeoIP.dat':
      'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat',
  'GeoSite.dat':
      'https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat',
};

Future<void> ensureGeoData({required String rootDir}) async {
  final dataDir = Directory(p.join(rootDir, 'assets', 'data'));
  if (!dataDir.existsSync()) {
    dataDir.createSync(recursive: true);
  }

  for (final entry in _geoDataFiles.entries) {
    final file = File(p.join(dataDir.path, entry.key));
    if (file.existsSync()) {
      _log.fine('GeoData exists: ${entry.key}');
      continue;
    }
    await _downloadGeoData(url: entry.value, file: file);
  }
}

Future<void> _downloadGeoData({
  required String url,
  required File file,
}) async {
  final tempFile = File('${file.path}.download');
  _log.info('Downloading GeoData: ${p.basename(file.path)}');

  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Failed to download $url: HTTP ${response.statusCode}',
        uri: Uri.parse(url),
      );
    }

    await response.pipe(tempFile.openWrite());
    if (file.existsSync()) {
      file.deleteSync();
    }
    tempFile.renameSync(file.path);
  } catch (_) {
    if (tempFile.existsSync()) {
      tempFile.deleteSync();
    }
    rethrow;
  } finally {
    client.close(force: true);
  }
}
