import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'tray_capabilities.dart';
import 'tray_codec.dart';
import 'tray_event.dart';
import 'tray_menu.dart';
import 'tray_spec.dart';

const String _methodShow = 'show';
const String _methodHide = 'hide';
const String _methodSetTitle = 'setTitle';
const String _methodOpenMenu = 'openMenu';
const String _methodUpdateMenuItem = 'updateMenuItem';

const String _eventIconActivated = 'onIconActivated';
const String _eventMenuRequested = 'onMenuRequested';
const String _eventMenuItemSelected = 'onMenuItemSelected';

final class Tray {
  Tray._() {
    _channel.setMethodCallHandler(_onPlatformCall);
  }

  static final Tray instance = Tray._();

  final MethodChannel _channel = const MethodChannel('tray');

  final StreamController<TrayEvent> _events =
      StreamController<TrayEvent>.broadcast();

  Map<int, TrayMenuItem> _itemsById = const {};
  Future<void> _queue = Future<void>.value();
  String? _signature;
  String _title = '';
  String _requestedTitle = '';
  bool _isVisible = false;

  Stream<TrayEvent> get events => _events.stream;

  TrayCapabilities get capabilities =>
      TrayCapabilities.of(defaultTargetPlatform);

  bool get isVisible => _isVisible;

  Future<void> show(TraySpec spec) {
    return _serialize(() => _show(spec));
  }

  Future<void> setTitle(String title) {
    _requestedTitle = title;
    return _serialize(() => _setTitle(_requestedTitle));
  }

  Future<void> hide() {
    return _serialize(_hide);
  }

  Future<void> openMenu({bool bringAppToFront = false}) {
    return _dispatch(() => _openMenu(bringAppToFront));
  }

  Future<bool> updateMenuItem({
    required String key,
    String? label,
    bool? enabled,
    bool? checked,
    String? sublabel,
    TrayMenuSublabelStyle? sublabelStyle,
  }) {
    return _serialize(
      () => _updateMenuItem(
        key: key,
        label: label,
        enabled: enabled,
        checked: checked,
        sublabel: sublabel,
        sublabelStyle: sublabelStyle,
      ),
    );
  }

  @visibleForTesting
  void resetForTesting() {
    _itemsById = const {};
    _queue = Future<void>.value();
    _signature = null;
    _title = '';
    _requestedTitle = '';
    _isVisible = false;
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<T> _dispatch<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) {
      try {
        action().then(completer.complete, onError: completer.completeError);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _show(TraySpec spec) async {
    if (!capabilities.supported) {
      return;
    }
    final encoded = TrayCodec.encode(spec);
    if (_isVisible && encoded.signature == _signature) {
      _itemsById = encoded.itemsById;
      return;
    }
    final isApplied = await _channel
        .invokeMethod<bool>(_methodShow, <String, Object?>{
          'id': _stableId,
          'icon': await _resolveIcon(spec.icon),
          'toolTip': encoded.toolTip,
          'title': _title,
          'menu': encoded.menu,
          'brightness': spec.brightness.name,
        });
    if (isApplied != true) {
      _signature = null;
      return;
    }
    _itemsById = encoded.itemsById;
    _signature = encoded.signature;
    _isVisible = true;
  }

  Future<void> _setTitle(String title) async {
    if (!capabilities.title) {
      return;
    }
    final isUnchanged = _title == title;
    _title = title;
    if (isUnchanged || !_isVisible) {
      return;
    }
    await _channel.invokeMethod(_methodSetTitle, <String, Object?>{
      'title': title,
    });
  }

  Future<void> _hide() async {
    _itemsById = const {};
    _signature = null;
    _title = '';
    if (!_isVisible) {
      return;
    }
    _isVisible = false;
    await _channel.invokeMethod(_methodHide);
  }

  Future<void> _openMenu(bool bringAppToFront) async {
    if (!capabilities.menuControl || !_isVisible) {
      return;
    }
    await _channel.invokeMethod(_methodOpenMenu, <String, Object?>{
      'bringAppToFront': bringAppToFront,
    });
  }

  Future<bool> _updateMenuItem({
    required String key,
    String? label,
    bool? enabled,
    bool? checked,
    String? sublabel,
    TrayMenuSublabelStyle? sublabelStyle,
  }) async {
    if (!_isVisible) {
      return false;
    }
    final arguments = <String, Object?>{'key': key};
    if (label != null) {
      arguments['label'] = label;
    }
    if (enabled != null) {
      arguments['enabled'] = enabled;
    }
    if (checked != null) {
      arguments['checked'] = checked;
    }
    if (sublabel != null) {
      arguments['sublabel'] = sublabel;
    }
    if (sublabelStyle != null) {
      arguments['sublabelStyle'] = sublabelStyle.name;
    }
    final applied = await _channel.invokeMethod<bool>(
      _methodUpdateMenuItem,
      arguments,
    );
    if (applied == true) {
      _signature = null;
      return true;
    }
    return false;
  }

  Future<void> _onPlatformCall(MethodCall call) async {
    switch (call.method) {
      case _eventIconActivated:
        _events.add(const TrayIconActivated());
      case _eventMenuRequested:
        _events.add(const TrayMenuRequested());
      case _eventMenuItemSelected:
        final arguments = call.arguments;
        if (arguments is! Map) {
          return;
        }
        final id = arguments['id'];
        final item = id is int ? _itemsById[id] : null;
        if (item == null) {
          return;
        }
        switch (item) {
          case TrayMenuAction(:final onSelected):
            onSelected?.call();
          case TrayMenuCheckbox(:final onSelected):
            onSelected?.call();
          case TrayMenuSubmenu():
          case TrayMenuSeparator():
            return;
        }
        _events.add(TrayMenuItemSelected(item));
    }
  }

  Future<Map<String, Object?>> _resolveIcon(TrayIcon icon) async {
    final resolved = <String, Object?>{
      'isTemplate': icon.isTemplate,
      'size': icon.size,
      'position': icon.position.name,
    };
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final data = await rootBundle.load(icon.asset);
      resolved['bytes'] = base64Encode(data.buffer.asUint8List());
    } else {
      resolved['path'] = path.joinAll([
        path.dirname(Platform.resolvedExecutable),
        'data',
        'flutter_assets',
        icon.asset,
      ]);
    }
    return resolved;
  }

  String get _stableId {
    return path.basenameWithoutExtension(Platform.resolvedExecutable);
  }
}
