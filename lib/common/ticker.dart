import 'dart:async';

import 'package:fl_clash/enum/enum.dart';

import 'function.dart';
import 'print.dart';

typedef ForegroundTickerCallback = FutureOr<void> Function();

class ForegroundTicker {
  static const _defaultInterval = Duration(seconds: 1);
  static const _defaultSlowInterval = Duration(seconds: 2);

  Duration _interval;
  Duration _slowInterval;

  final _tasks = <Object, _ForegroundTickerTask>{};
  Timer? _timer;
  late Duration _currentInterval;
  bool _active = true;

  ForegroundTicker({
    Duration interval = _defaultInterval,
    Duration slowInterval = _defaultSlowInterval,
  }) : _interval = _safeInterval(interval, _defaultInterval),
       _slowInterval = _safeInterval(slowInterval, _defaultSlowInterval) {
    _currentInterval = _interval;
  }

  Duration get interval => _interval;

  Duration get slowInterval => _slowInterval;

  static Duration _safeInterval(Duration value, Duration fallback) {
    return value > Duration.zero ? value : fallback;
  }

  void updateSettings({
    required Duration interval,
    required Duration slowInterval,
  }) {
    final wasSlow = _currentInterval == _slowInterval;
    _interval = _safeInterval(interval, _defaultInterval);
    _slowInterval = _safeInterval(slowInterval, _defaultSlowInterval);
    _setInterval(wasSlow ? _slowInterval : _interval);
  }

  void register(
    Object tag,
    ForegroundTickerCallback callback, {
    bool fire = false,
  }) {
    final task = _ForegroundTickerTask(callback: callback);
    _tasks[tag] = task;
    if (fire && _active) {
      _runTask(task);
    }
    _syncTimer();
  }

  void unregister(Object tag) {
    _tasks.remove(tag);
    _syncTimer();
  }

  void pause() {
    throttler.cancel(FunctionTag.tickerResume);
    debouncer.call(FunctionTag.tickerPause, _pause, duration: interval);
  }

  void slow() {
    if (!_active) {
      return;
    }
    _setInterval(slowInterval);
  }

  void resume() {
    debouncer.cancel(FunctionTag.tickerPause);
    throttler.call(
      FunctionTag.tickerResume,
      _resume,
      duration: interval,
      fire: true,
    );
  }

  void dispose() {
    debouncer.cancel(FunctionTag.tickerPause);
    throttler.cancel(FunctionTag.tickerResume);
    _pause();
    _tasks.clear();
  }

  void _pause() {
    if (!_active) {
      return;
    }
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  void _resume() {
    final wasActive = _active;
    final wasSlow = _currentInterval != interval;
    _active = true;
    _setInterval(interval);
    if (!wasActive || wasSlow) {
      _tick();
    }
  }

  void _syncTimer() {
    if (!_active || _tasks.isEmpty) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(_currentInterval, (_) {
      _tick();
    });
  }

  void _setInterval(Duration interval) {
    if (_currentInterval == interval) {
      _syncTimer();
      return;
    }
    _currentInterval = interval;
    _timer?.cancel();
    _timer = null;
    _syncTimer();
  }

  void _tick() {
    if (!_active) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    for (final task in List<_ForegroundTickerTask>.from(_tasks.values)) {
      if (task.isRunning) {
        continue;
      }
      _runTask(task);
    }
  }

  void _runTask(_ForegroundTickerTask task) {
    task.isRunning = true;
    Future.sync(task.callback)
        .catchError((Object e, StackTrace s) {
          commonPrint.log('global ticker task error: $e, $s');
        })
        .whenComplete(() {
          task.isRunning = false;
        });
  }
}

class _ForegroundTickerTask {
  final ForegroundTickerCallback callback;
  bool isRunning = false;

  _ForegroundTickerTask({required this.callback});
}

final foregroundTicker = ForegroundTicker();
