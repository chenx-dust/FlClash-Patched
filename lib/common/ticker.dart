import 'dart:async';

import 'print.dart';

typedef ForegroundTickerCallback = FutureOr<void> Function();

class ForegroundTicker {
  static const interval = Duration(seconds: 1);

  final _tasks = <Object, _ForegroundTickerTask>{};
  Timer? _timer;
  bool _active = true;

  void register(
    Object tag,
    ForegroundTickerCallback callback, {
    bool runImmediately = false,
  }) {
    final task = _ForegroundTickerTask(callback: callback);
    _tasks[tag] = task;
    if (runImmediately && _active) {
      _runTask(task);
    }
    _syncTimer();
  }

  void unregister(Object tag) {
    _tasks.remove(tag);
    _syncTimer();
  }

  void pause() {
    if (!_active) {
      return;
    }
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    if (_active) {
      return;
    }
    _active = true;
    _syncTimer();
    _tick();
  }

  void dispose() {
    pause();
    _tasks.clear();
  }

  void _syncTimer() {
    if (!_active || _tasks.isEmpty) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(interval, (_) {
      _tick();
    });
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
