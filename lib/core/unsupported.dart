import 'dart:async';

import 'package:fl_clash/enum/enum.dart';

import 'interface.dart';

class CoreUnsupported extends CoreHandlerInterface {
  static CoreUnsupported? _instance;

  final Completer<bool> _completer = Completer<bool>()..complete(false);

  CoreUnsupported._internal();

  factory CoreUnsupported() {
    _instance ??= CoreUnsupported._internal();
    return _instance!;
  }

  @override
  FutureOr<bool> destroy() {
    return true;
  }

  @override
  Future<String> preload() async {
    return 'Current platform core is not implemented';
  }

  @override
  Future<bool> shutdown(bool isUser) async {
    return true;
  }

  @override
  Future<T?> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
  }) async {
    return null;
  }

  @override
  Completer get completer => _completer;
}

final coreUnsupported = CoreUnsupported();
