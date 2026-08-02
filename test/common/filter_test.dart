import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('LogsState.list', () {
    Log log(
      LogLevel level,
      String payload, {
      LogSource source = LogSource.app,
    }) => Log(
      logLevel: level,
      source: source,
      payload: payload,
      timestamp: 0,
    );

    test('returns all logs when no filters and empty query', () {
      final state = LogsState(
        logs: [
          log(LogLevel.info, 'test message'),
          log(LogLevel.error, 'error occurred'),
        ],
      );
      expect(state.list.length, 2);
    });

    test('filters by selected log level', () {
      final state = LogsState(
        logs: [
          log(LogLevel.info, 'info msg'),
          log(LogLevel.error, 'error msg'),
          log(LogLevel.debug, 'debug msg'),
        ],
        levels: {LogLevel.info, LogLevel.debug},
      );
      expect(state.list.length, 2);
      expect(state.list[0].logLevel, LogLevel.info);
      expect(state.list[1].logLevel, LogLevel.debug);
    });

    test('filters by selected log source', () {
      final state = LogsState(
        logs: [
          log(LogLevel.info, 'app msg'),
          log(LogLevel.info, 'core msg', source: LogSource.core),
        ],
        sources: {LogSource.core},
      );
      expect(state.list.length, 1);
      expect(state.list[0].source, LogSource.core);
    });

    test('combines selected filters with query', () {
      final state = LogsState(
        logs: [
          log(LogLevel.info, 'timeout', source: LogSource.core),
          log(LogLevel.error, 'timeout', source: LogSource.core),
          log(LogLevel.error, 'connected', source: LogSource.core),
          log(LogLevel.error, 'timeout', source: LogSource.app),
        ],
        sources: {LogSource.core},
        levels: {LogLevel.error},
        query: 'timeout',
      );
      expect(state.list.length, 1);
      expect(state.list[0].logLevel, LogLevel.error);
      expect(state.list[0].source, LogSource.core);
      expect(state.list[0].payload, 'timeout');
    });

    test('filters by query matching payload', () {
      final state = LogsState(
        logs: [
          log(LogLevel.info, 'connection established'),
          log(LogLevel.info, 'timeout error'),
        ],
        query: 'timeout',
      );
      expect(state.list.length, 1);
      expect(state.list[0].payload, 'timeout error');
    });

    test('query is case insensitive', () {
      final state = LogsState(
        logs: [log(LogLevel.info, 'Connection Established')],
        query: 'connection',
      );
      expect(state.list.length, 1);
    });

    test('empty result when no match', () {
      final state = LogsState(
        logs: [log(LogLevel.info, 'hello')],
        query: 'nonexistent',
      );
      expect(state.list, isEmpty);
    });
  });

  group('TrackerInfosState.list', () {
    Metadata meta({
      String network = 'tcp',
      String host = 'example.com',
      String destinationIP = '1.2.3.4',
      String process = 'chrome',
    }) => Metadata(
      network: network,
      host: host,
      destinationIP: destinationIP,
      process: process,
    );

    TrackerInfo tracker(
      String id, {
      List<String> chains = const ['proxy-a'],
      Metadata? metadata,
    }) => TrackerInfo(
      id: id,
      start: DateTime(2024),
      metadata: metadata ?? meta(),
      chains: chains,
      rule: 'MATCH',
      rulePayload: '',
    );

    test('returns all when no keywords and empty query', () {
      final state = TrackerInfosState(trackerInfos: [tracker('1')]);
      expect(state.list.length, 1);
    });

    test('filters by keyword matching chain name', () {
      final state = TrackerInfosState(
        trackerInfos: [
          tracker('1', chains: ['proxy-a', 'proxy-b']),
          tracker('2', chains: ['proxy-c']),
        ],
        keywords: ['proxy-a'],
      );
      expect(state.list.length, 1);
      expect(state.list[0].id, '1');
    });

    test('filters by keyword matching process', () {
      final state = TrackerInfosState(
        trackerInfos: [
          tracker('1', metadata: meta(process: 'chrome')),
          tracker('2', metadata: meta(process: 'firefox')),
        ],
        keywords: ['firefox'],
      );
      expect(state.list.length, 1);
      expect(state.list[0].id, '2');
    });

    test('query matches host', () {
      final state = TrackerInfosState(
        trackerInfos: [
          tracker('1', metadata: meta(host: 'google.com')),
          tracker('2', metadata: meta(host: 'github.com')),
        ],
        query: 'github',
      );
      expect(state.list.length, 1);
      expect(state.list[0].id, '2');
    });

    test('query matches network', () {
      final state = TrackerInfosState(
        trackerInfos: [
          tracker('1', metadata: meta(network: 'tcp')),
          tracker('2', metadata: meta(network: 'udp')),
        ],
        query: 'udp',
      );
      expect(state.list.length, 1);
      expect(state.list[0].id, '2');
    });

    test('query matches destinationIP', () {
      final state = TrackerInfosState(
        trackerInfos: [
          tracker('1', metadata: meta(destinationIP: '10.0.0.1')),
          tracker('2', metadata: meta(destinationIP: '192.168.1.1')),
        ],
        query: '192.168',
      );
      expect(state.list.length, 1);
      expect(state.list[0].id, '2');
    });

    test('query matches chains text', () {
      final state = TrackerInfosState(
        trackerInfos: [
          tracker('1', chains: ['proxy-a']),
          tracker('2', chains: ['proxy-b']),
        ],
        query: 'proxy-b',
      );
      expect(state.list.length, 1);
      expect(state.list[0].id, '2');
    });
  });
}
