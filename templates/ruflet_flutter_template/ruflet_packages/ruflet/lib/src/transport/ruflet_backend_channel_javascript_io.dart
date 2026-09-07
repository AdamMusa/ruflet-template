import '../protocol/message.dart';
import 'ruflet_backend_channel.dart';

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
  connect() async {}

  @override
  bool get isLocalConnection => true;

  @override
  int get defaultReconnectIntervalMs => 10;

  @override
  void send(Message data) {}

  @override
  void disconnect() {}
}
