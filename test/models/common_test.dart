import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('PackagesExt', () {
    const packages = [
      Package(
        packageName: 'system.app',
        label: 'System',
        system: true,
        internet: true,
        lastUpdateTime: 1,
      ),
      Package(
        packageName: 'user.old',
        label: 'Alpha',
        system: false,
        internet: false,
        lastUpdateTime: 2,
      ),
      Package(
        packageName: 'user.new',
        label: 'Beta',
        system: false,
        internet: true,
        lastUpdateTime: 3,
      ),
    ];

    test('filters system and non-internet apps', () {
      final result = packages.getViewList(
        pinedList: [],
        sortType: AccessSortType.none,
        isFilterSystemApp: true,
        isFilterNonInternetApp: true,
      );

      expect(result.map((item) => item.packageName), ['user.new']);
    });

    test('pins selected packages before sorted packages', () {
      final result = packages.getViewList(
        pinedList: ['user.old'],
        sortType: AccessSortType.name,
        isFilterSystemApp: false,
        isFilterNonInternetApp: false,
      );

      expect(result.map((item) => item.packageName), [
        'user.old',
        'user.new',
        'system.app',
      ]);
    });
  });

  group('TrackerInfoExt', () {
    final previous = TrackerInfo(
      id: 'connection',
      upload: 100,
      download: 200,
      start: DateTime(2026),
      metadata: const Metadata(),
      chains: const ['Proxy'],
      rule: 'DIRECT',
      rulePayload: '',
    );

    test('builds destination description and process text', () {
      final trackerInfo = TrackerInfo(
        id: '1',
        start: DateTime(2026),
        metadata: const Metadata(
          network: 'tcp',
          host: 'example.com',
          destinationIP: '1.1.1.1',
          destinationPort: '443',
          process: 'Browser',
          uid: 501,
        ),
        chains: const ['Proxy'],
        rule: 'MATCH',
        rulePayload: '',
      );

      expect(trackerInfo.desc, 'tcp://example.com/1.1.1.1:443');
      expect(trackerInfo.progressText, 'Browser(501)');
    });

    test('calculates upload and download speed from elapsed time', () {
      final current = previous.copyWith(upload: 1124, download: 2248);

      final result = current.withCalculatedSpeed(
        previous: previous,
        elapsed: const Duration(seconds: 2),
      );

      expect(result.uploadSpeed, 512);
      expect(result.downloadSpeed, 1024);
    });

    test('clamps reset traffic counters to zero speed', () {
      final current = previous.copyWith(upload: 50, download: 100);

      final result = current.withCalculatedSpeed(
        previous: previous,
        elapsed: const Duration(seconds: 1),
      );

      expect(result.uploadSpeed, 0);
      expect(result.downloadSpeed, 0);
    });

    test('does not calculate speed without a valid matching sample', () {
      final current = previous.copyWith(id: 'new-connection');

      expect(
        current.withCalculatedSpeed(
          previous: previous,
          elapsed: const Duration(seconds: 1),
        ),
        same(current),
      );
      expect(
        previous.withCalculatedSpeed(
          previous: previous,
          elapsed: Duration.zero,
        ),
        same(previous),
      );
    });
  });

  group('TrafficExt', () {
    test('formats speed, description, tray title, and total speed', () {
      const traffic = Traffic(up: 1024, down: 2048);

      expect(traffic.speedText, '↑ 1KB/s   ↓ 2KB/s');
      expect(traffic.desc, '1KB ↑ 2KB ↓');
      expect(traffic.trayTitle, '1 KB/s\n2 KB/s');
      expect(traffic.speed, 3072);
      expect(traffic.speedDesc, '1KB/s ↑ 2KB/s ↓');
    });
  });

  group('GroupsExt', () {
    test('finds group by name and resolves current selection', () {
      const groups = [
        Group(name: 'Auto', type: GroupType.URLTest, now: 'Proxy A'),
        Group(name: 'Manual', type: GroupType.Selector, now: 'Proxy B'),
      ];

      expect(
        groups.getGroup('Auto')?.getCurrentSelectedName('Proxy C'),
        'Proxy A',
      );
      expect(
        groups.getGroup('Manual')?.getCurrentSelectedName('Proxy C'),
        'Proxy C',
      );
      expect(groups.getGroup('Missing'), isNull);
    });
  });

  group('IpInfo parsers', () {
    test('parse supported response shapes', () {
      expect(
        IpInfo.fromIpInfoIoJson({'ip': '1.1.1.1', 'country': 'US'}),
        const IpInfo(ip: '1.1.1.1', countryCode: 'US'),
      );
      expect(
        IpInfo.fromMyIpJson({'ip': '2.2.2.2', 'cc': 'JP'}),
        const IpInfo(ip: '2.2.2.2', countryCode: 'JP'),
      );
      expect(
        IpInfo.fromIpAPIJson({'query': '3.3.3.3', 'countryCode': 'CN'}),
        const IpInfo(ip: '3.3.3.3', countryCode: 'CN'),
      );
    });

    test('throw FormatException for unsupported response shapes', () {
      expect(
        () => IpInfo.fromIpInfoIoJson({'ip': '1.1.1.1'}),
        throwsFormatException,
      );
      expect(
        () => IpInfo.fromIpApiCoJson({'ip': '1.1.1.1'}),
        throwsFormatException,
      );
    });
  });

  group('ResultExt', () {
    test('identifies success and error results', () {
      final success = Result.success('ok');
      final error = Result<Object>.error('failed');

      expect(success.isSuccess, isTrue);
      expect(success.isError, isFalse);
      expect(error.isSuccess, isFalse);
      expect(error.isError, isTrue);
    });
  });
}
