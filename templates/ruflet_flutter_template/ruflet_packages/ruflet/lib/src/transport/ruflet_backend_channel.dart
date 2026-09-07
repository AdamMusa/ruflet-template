import '../protocol/message.dart';
import '../utils/platform_utils_web.dart'
    if (dart.library.io) "../utils/platform_utils_non_web.dart";
import 'ruflet_backend_channel_javascript_web.dart'
    if (dart.library.io) "ruflet_backend_channel_javascript_io.dart";
import 'ruflet_backend_channel_mock.dart';
import 'ruflet_backend_channel_socket.dart';
import 'ruflet_backend_channel_web_socket.dart';

typedef RufletBackendChannelOnDisconnectCallback = void Function();
typedef RufletBackendChannelOnMessageCallback = void Function(Message message);
typedef RufletBackendChannelBuilder = RufletBackendChannel Function({
  required String address,
  required Map<String, dynamic> args,
  required bool forcePyodide,
  required RufletBackendChannelOnDisconnectCallback onDisconnect,
  required RufletBackendChannelOnMessageCallback onMessage,
});

abstract class RufletBackendChannel {
  factory RufletBackendChannel(
      {required String address,
      required Map<String, dynamic> args,
      required bool forcePyodide,
      required RufletBackendChannelOnDisconnectCallback onDisconnect,
      required RufletBackendChannelOnMessageCallback onMessage}) {
    if (isPyodideMode() || forcePyodide) {
      // Pyodide/JavaScript
      return RufletJavaScriptBackendChannel(
          address: address,
          args: args,
          onDisconnect: onDisconnect,
          onMessage: onMessage);
    } else if (address.startsWith("http://") ||
        address.startsWith("https://")) {
      // WebSocket
      return RufletWebSocketBackendChannel(
          address: address, onDisconnect: onDisconnect, onMessage: onMessage);
    } else if (address == "mock") {
      // Mock
      return RufletMockBackendChannel(
          address: address, onDisconnect: onDisconnect, onMessage: onMessage);
    } else {
      // TCP or UDS
      return RufletSocketBackendChannel(
          address: address, onDisconnect: onDisconnect, onMessage: onMessage);
    }
  }

  Future connect();
  bool get isLocalConnection;
  int get defaultReconnectIntervalMs;
  void send(Message message);
  void disconnect();
}
