import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;

import '../protocol/message.dart';
import 'ruflet_backend_channel.dart';
import 'ruflet_msgpack_decoder.dart';
import 'ruflet_msgpack_encoder.dart';

@JS()
external JSPromise jsConnect(
    String appId, JSAny args, JSExportedDartFunction onMessage);

@JS()
external void jsSend(String appId, JSUint8Array data);

@JS()
external void jsDisconnect(String appId);

typedef RufletBackendJavascriptChannelOnMessageCallback = void Function(
    List<int> message);

class RufletJavaScriptBackendChannel implements RufletBackendChannel {
  final String address;
  final Map<String, dynamic> args;
  final RufletBackendChannelOnMessageCallback onMessage;
  final RufletBackendChannelOnDisconnectCallback onDisconnect;

  RufletJavaScriptBackendChannel(
      {required this.address,
      required this.args,
      required this.onDisconnect,
      required this.onMessage});

  @override
  connect() async {
    debugPrint("Connecting to Ruflet JavaScript channel $address...");
    await jsConnect(address, args.jsify()!, _onMessage.toJS).toDart;
  }

  void _onMessage(JSUint8Array data) {
    onMessage(Message.fromList(
        msgpack.deserialize(data.toDart, extDecoder: RufletMsgpackDecoder())));
  }

  @override
  bool get isLocalConnection => true;

  @override
  int get defaultReconnectIntervalMs => 10000;

  @override
  void send(Message message) {
    jsSend(
        address,
        msgpack
            .serialize(message.toList(), extEncoder: RufletMsgpackEncoder())
            .toJS);
  }

  @override
  void disconnect() {
    jsDisconnect(address);
  }
}
