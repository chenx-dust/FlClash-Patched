import 'dart:async';
import 'dart:math';

import 'package:fl_clash/common/function.dart';
import 'package:test/test.dart';

void main() {
  group('SerialLatestTaskScheduler', () {
    test('serializes tasks in submission order', () async {
      final scheduler = SerialLatestTaskScheduler();
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final events = <String>[];
      var runningTasks = 0;
      var maxRunningTasks = 0;

      final first = scheduler.run(() async {
        runningTasks++;
        maxRunningTasks = max(maxRunningTasks, runningTasks);
        firstStarted.complete();
        await releaseFirst.future;
        events.add('first');
        runningTasks--;
      });
      await firstStarted.future;

      final second = scheduler.run(() async {
        runningTasks++;
        maxRunningTasks = max(maxRunningTasks, runningTasks);
        events.add('second');
        runningTasks--;
      });
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
      releaseFirst.complete();
      await Future.wait([first, second]);

      expect(events, ['first', 'second']);
      expect(maxRunningTasks, 1);
    });

    test('keeps only the latest pending profile setup', () async {
      final scheduler = SerialLatestTaskScheduler();
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final preparedProfiles = <String>[];
      final appliedProfiles = <String>[];

      Future<void> setupProfile(
        String profile,
        bool Function() isLatest, {
        Completer<void>? started,
        Future<void>? waitFor,
      }) async {
        preparedProfiles.add(profile);
        started?.complete();
        if (waitFor != null) {
          await waitFor;
        }
        if (isLatest()) {
          appliedProfiles.add(profile);
        }
      }

      final first = scheduler.runLatest((isLatest) {
        return setupProfile(
          'A',
          isLatest,
          started: firstStarted,
          waitFor: releaseFirst.future,
        );
      });
      await firstStarted.future;

      final second = scheduler.runLatest((isLatest) {
        return setupProfile('B', isLatest);
      });
      final third = scheduler.runLatest((isLatest) {
        return setupProfile('C', isLatest);
      });
      releaseFirst.complete();
      await Future.wait([first, second, third]);

      expect(preparedProfiles, ['A', 'C']);
      expect(appliedProfiles, ['C']);
    });

    test('continues after a failed serialized task', () async {
      final scheduler = SerialLatestTaskScheduler();

      await expectLater(
        scheduler.run<void>(() async {
          throw StateError('failed');
        }),
        throwsStateError,
      );

      final result = await scheduler.run(() async => 'next');
      expect(result, 'next');
    });
  });

  group('retry', () {
    test('returns immediately when first result does not need retry', () async {
      var attempts = 0;

      final result = await retry(
        task: () async {
          attempts++;
          return 'done';
        },
        retryIf: (res) => res != 'done',
        delay: Duration.zero,
      );

      expect(result, 'done');
      expect(attempts, 1);
    });

    test('retries until result no longer matches retry condition', () async {
      var attempts = 0;

      final result = await retry(
        task: () async {
          attempts++;
          return attempts < 3 ? 'pending' : 'done';
        },
        retryIf: (res) => res == 'pending',
        delay: Duration.zero,
        maxAttempts: 5,
      );

      expect(result, 'done');
      expect(attempts, 3);
    });

    test('returns last result when max attempts are exhausted', () async {
      var attempts = 0;

      final result = await retry(
        task: () async {
          attempts++;
          return false;
        },
        retryIf: (res) => res == false,
        delay: Duration.zero,
        maxAttempts: 3,
      );

      expect(result, false);
      expect(attempts, 3);
    });

    test('waits between retry attempts', () async {
      var attempts = 0;

      final future = retry(
        task: () async {
          attempts++;
          return attempts < 2 ? 'pending' : 'done';
        },
        retryIf: (res) => res == 'pending',
        delay: const Duration(milliseconds: 50),
        maxAttempts: 2,
      );

      await Future.delayed(const Duration(milliseconds: 10));
      expect(attempts, 1);

      final result = await future;

      expect(result, 'done');
      expect(attempts, 2);
    });
  });
}
