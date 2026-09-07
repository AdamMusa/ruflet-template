import 'dart:async';
import 'dart:typed_data';

import 'package:ruflet/src/protocol/message.dart';
import 'package:ruflet/src/transport/ruflet_backend_channel_in_process.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;

void main() {
  test('preserves one MessagePack protocol message per bridge frame', () async {
    final firstIncoming = Completer<Uint8List?>();
    final waitingAfterFirst = Completer<Uint8List?>();
    var receiveCount = 0;
    final received = Completer<Message>();
    final sent = Completer<Uint8List>();
    var disconnected = false;

    final channel = RufletInProcessBackendChannel(
      sendBytes: (message) async => sent.complete(message),
      receiveBytes: () =>
          receiveCount++ == 0 ? firstIncoming.future : waitingAfterFirst.future,
      closeBytes: () async => waitingAfterFirst.complete(null),
      onDisconnect: () => disconnected = true,
      onMessage: received.complete,
    );

    await channel.connect();
    firstIncoming.complete(
      Uint8List.fromList(
        msgpack.serialize([
          MessageAction.patchControl.value,
          {'id': 42},
        ]),
      ),
    );

    final message = await received.future;
    expect(message.action, MessageAction.patchControl);
    expect(message.payload, {'id': 42});
    expect(disconnected, isFalse);

    channel.send(
      Message(action: MessageAction.controlEvent, payload: {'target': 9}),
    );
    final encoded = await sent.future;
    expect(msgpack.deserialize(encoded), [
      MessageAction.controlEvent.value,
      {'target': 9},
    ]);
    channel.disconnect();
  });

  test('closed bridge reports disconnect without another transport', () async {
    final disconnected = Completer<void>();
    final channel = RufletInProcessBackendChannel(
      sendBytes: (_) async {},
      receiveBytes: () async => null,
      closeBytes: () async {},
      onDisconnect: disconnected.complete,
      onMessage: (_) {},
    );

    await channel.connect();
    await disconnected.future;

    expect(disconnected.isCompleted, isTrue);
  });
}
