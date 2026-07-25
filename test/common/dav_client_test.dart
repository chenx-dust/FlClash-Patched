import 'dart:async';

import 'package:fl_clash/common/dav_client.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDAVClient extends DAVClient {
  _FakeDAVClient(super.dav, super.password, this.result, [this.onPing]);

  final Future<bool> result;
  final void Function()? onPing;

  @override
  Future<bool> ping() {
    onPing?.call();
    return result;
  }
}

void main() {
  const firstProps = DAVProps(uri: 'https://dav.example.com', user: 'first');
  const secondProps = DAVProps(uri: 'https://dav.example.com', user: 'second');

  test('latest DAV connectivity check wins', () async {
    final firstResult = Completer<bool>();
    final secondResult = Completer<bool>();
    final results = [firstResult.future, secondResult.future];
    var index = 0;
    final controller = DAVConnectionController(
      createClient: (props, password) {
        return _FakeDAVClient(props, password, results[index++]);
      },
    );
    addTearDown(controller.dispose);

    final firstUpdate = controller.update(firstProps, 'first-password');
    final secondUpdate = controller.update(secondProps, 'second-password');

    secondResult.complete(true);
    await secondUpdate;
    expect(controller.value, isTrue);

    firstResult.complete(false);
    await firstUpdate;
    expect(controller.value, isTrue);
  });

  test('changing only the remote file name does not ping again', () async {
    var pingCount = 0;
    final controller = DAVConnectionController(
      createClient: (props, password) {
        return _FakeDAVClient(
          props,
          password,
          Future.value(true),
          () => pingCount++,
        );
      },
    );
    addTearDown(controller.dispose);

    await controller.update(firstProps, 'password');
    await controller.update(
      firstProps.copyWith(fileName: 'another.zip'),
      'password',
    );

    expect(pingCount, 1);
    expect(controller.value, isTrue);
    expect(controller.client?.fileName, 'another.zip');
  });

  test('new credentials reset connectivity while ping is pending', () async {
    final result = Completer<bool>();
    final controller = DAVConnectionController(
      createClient: (props, password) {
        return _FakeDAVClient(props, password, result.future);
      },
    );
    addTearDown(controller.dispose);

    final update = controller.update(firstProps, 'password');

    expect(controller.value, isNull);
    result.complete(true);
    await update;
    expect(controller.value, isTrue);
  });
}
