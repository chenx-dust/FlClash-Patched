import 'package:fl_clash/common/ticker.dart';
import 'package:test/test.dart';

void main() {
  group('ForegroundTicker', () {
    const interval = Duration(milliseconds: 50);

    test('pause is debounced before stopping immediate task runs', () async {
      final ticker = ForegroundTicker(interval: interval);
      var runs = 0;

      ticker.pause();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      ticker.register(Object(), () {
        runs++;
      }, fire: true);

      expect(runs, 1);

      ticker.dispose();
    });

    test('pause eventually stops immediate task runs', () async {
      final ticker = ForegroundTicker(interval: interval);
      var runs = 0;

      ticker.pause();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      ticker.register(Object(), () {
        runs++;
      }, fire: true);

      expect(runs, 0);

      ticker.dispose();
    });

    test('resume cancels pending pause', () async {
      final ticker = ForegroundTicker(interval: interval);
      var runs = 0;

      ticker.pause();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      ticker.resume();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      ticker.register(Object(), () {
        runs++;
      }, fire: true);

      expect(runs, 1);

      ticker.dispose();
    });

    test('slow uses slow interval until resume restores normal interval', () async {
      final ticker = ForegroundTicker(
        interval: const Duration(milliseconds: 30),
        slowInterval: const Duration(milliseconds: 120),
      );
      var runs = 0;

      ticker.register(Object(), () {
        runs++;
      });

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(runs, greaterThanOrEqualTo(2));

      ticker.slow();
      final slowStartRuns = runs;
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(runs, slowStartRuns);

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(runs, greaterThanOrEqualTo(slowStartRuns + 1));

      ticker.resume();
      final resumeStartRuns = runs;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(runs, greaterThanOrEqualTo(resumeStartRuns + 2));

      ticker.dispose();
    });
  });
}
