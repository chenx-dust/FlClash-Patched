import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';

List<CoreEvent> coreEventsFromData(Object? data) {
  final items = data is List ? data : [data];
  final events = <CoreEvent>[];
  for (final item in items.whereType<Map>()) {
    try {
      final type = item['type'];
      if (type is! String ||
          !CoreEventType.values.any((eventType) => eventType.name == type)) {
        throw FormatException('Unknown Core event type: $type');
      }
      events.add(CoreEvent.fromJson(Map<String, Object?>.from(item)));
    } catch (error) {
      commonPrint.log(
        'Unable to parse Core event: $error',
        logLevel: LogLevel.error,
      );
    }
  }
  return events;
}

abstract mixin class CoreEventListener {
  FutureOr<void> onLog(Log log) {}

  FutureOr<void> onDelay(Delay delay) {}

  FutureOr<void> onRequest(TrackerInfo connection) {}

  FutureOr<void> onLoaded(String providerName) {}

  FutureOr<void> onCrash(String message) {}

  FutureOr<void> onGeoUpdate(
    String geoType,
    bool updating,
    bool skipped,
    String? error,
  ) {}
}

class CoreEventManager {
  final _controller = StreamController<CoreEvent>();

  CoreEventManager._() {
    _controller.stream.listen((event) {
      for (final CoreEventListener listener in _listeners) {
        unawaited(_dispatch(event, listener));
      }
    });
  }

  Future<void> _dispatch(CoreEvent event, CoreEventListener listener) async {
    try {
      switch (event.type) {
        case CoreEventType.log:
          await listener.onLog(Log.fromJson(event.data));
        case CoreEventType.delay:
          await listener.onDelay(Delay.fromJson(event.data));
        case CoreEventType.request:
          await listener.onRequest(TrackerInfo.fromJson(event.data));
        case CoreEventType.loaded:
          await listener.onLoaded(event.data);
        case CoreEventType.crash:
          await listener.onCrash(event.data);
        case CoreEventType.geoUpdate:
          final data = event.data as Map<String, dynamic>;
          await listener.onGeoUpdate(
            data['type'] as String,
            data['updating'] as bool,
            data['skipped'] as bool? ?? false,
            data['error'] as String?,
          );
      }
    } catch (error) {
      commonPrint.log(
        'Unable to dispatch Core event ${event.type.name}: $error',
        logLevel: LogLevel.error,
      );
    }
  }

  static final CoreEventManager instance = CoreEventManager._();

  final ObserverList<CoreEventListener> _listeners =
      ObserverList<CoreEventListener>();

  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  void sendEvent(CoreEvent event) {
    _controller.add(event);
  }

  void addListener(CoreEventListener listener) {
    _listeners.add(listener);
  }

  void removeListener(CoreEventListener listener) {
    _listeners.remove(listener);
  }
}

final coreEventManager = CoreEventManager.instance;
