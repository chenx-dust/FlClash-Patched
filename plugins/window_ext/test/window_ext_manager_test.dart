import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_ext/window_ext.dart';

class _RecordingListener with WindowExtListener {
  final events = <String>[];

  @override
  Future<void> onWindowActivated() async => events.add('activated');

  @override
  Future<void> onShouldTerminate() async => events.add('terminate');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('window_ext');
  final listener = _RecordingListener();

  setUp(() => windowExtManager.addListener(listener));

  tearDown(() {
    windowExtManager.removeListener(listener);
    listener.events.clear();
  });

  Future<void> emit(String method) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
      null,
    );
  }

  test('dispatches activation and termination events', () async {
    await emit('windowActivated');
    await emit('shouldTerminate');

    expect(listener.events, ['activated', 'terminate']);
  });
}
