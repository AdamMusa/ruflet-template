import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;

import '../protocol/message.dart';
import 'ruflet_backend_channel.dart';
import 'ruflet_msgpack_decoder.dart';
import 'ruflet_msgpack_encoder.dart';

typedef RufletBinaryMessageSender = Future<void> Function(Uint8List message);
typedef RufletBinaryMessageReceiver = Future<Uint8List?> Function();
typedef RufletBinaryChannelCloser = Future<void> Function();

/// A Ruflet protocol channel over message-boundary-preserving in-memory bytes.
///
/// Runtime ownership stays outside Ruflet. Embedders provide three binary
/// operations, while Ruflet continues to own MessagePack and the protocol state
/// machine exactly as it does for socket transports.
class RufletInProcessBackendChannel implements RufletBackendChannel {
  RufletInProcessBackendChannel({
    required this.sendBytes,
    required this.receiveBytes,
    required this.closeBytes,
    required this.onDisconnect,
    required this.onMessage,
  });

  final RufletBinaryMessageSender sendBytes;
  final RufletBinaryMessageReceiver receiveBytes;
  final RufletBinaryChannelCloser closeBytes;
  final RufletBackendChannelOnDisconnectCallback onDisconnect;
  final RufletBackendChannelOnMessageCallback onMessage;

  bool _connected = false;
  Future<void> _sendChain = Future<void>.value();

  @override
  bool get isLocalConnection => true;

  @override
  int get defaultReconnectIntervalMs => 200;

  @override
  Future<void> connect() async {
    if (_connected) {
      throw StateError('Ruflet in-process channel is already connected.');
    }
    _connected = true;
    unawaited(_receiveMessages());
  }

  Future<void> _receiveMessages() async {
    try {
      while (_connected) {
        final bytes = await receiveBytes();
        if (!_connected) return;
        if (bytes == null) {
          _connected = false;
          onDisconnect();
          return;
        }

        final decoded = msgpack.deserialize(
          bytes,
          extDecoder: RufletMsgpackDecoder(),
        );
        if (decoded is! List) {
          throw const FormatException(
            'Ruflet in-process frame is not a protocol message.',
          );
        }
        onMessage(Message.fromList(List<dynamic>.from(decoded)));
      }
    } catch (error) {
      debugPrint('Ruflet in-process receive error: $error');
      if (_connected) {
        _connected = false;
        onDisconnect();
      }
    }
  }

  @override
  void send(Message message) {
    final bytes = Uint8List.fromList(
      msgpack.serialize(
        message.toList(),
        extEncoder: RufletMsgpackEncoder(),
      ),
    );
    _sendChain = _sendChain.then((_) async {
      if (!_connected) {
        throw StateError('Ruflet in-process channel is closed.');
      }
      await sendBytes(bytes);
    }).catchError((Object error) {
      debugPrint('Ruflet in-process send error: $error');
      if (_connected) {
        _connected = false;
        onDisconnect();
      }
    });
  }

  @override
  void disconnect() {
    if (!_connected) return;
    _connected = false;
    unawaited(closeBytes());
  }
}
