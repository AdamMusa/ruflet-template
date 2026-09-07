import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'controls/control_widget.dart';
import 'ruflet_app_errors_handler.dart';
import 'ruflet_backend.dart';
import 'ruflet_extension.dart';
import 'models/control.dart';
import 'testing/tester.dart';
import 'transport/ruflet_backend_channel.dart';

/// RufletApp - The top-level widget that initializes everything
class RufletApp extends StatefulWidget {
  final String pageUrl;
  final String assetsDir;
  final String? assetsBundlePath;
  final bool? showAppStartupScreen;
  final String? appStartupScreenMessage;
  final String? appErrorMessage;
  final int? controlId;
  final String? title;
  final RufletAppErrorsHandler? errorsHandler;
  final int? reconnectIntervalMs;
  final int? reconnectTimeoutMs;
  final List<RufletExtension>? extensions;
  final Map<String, dynamic>? args;
  final bool? forcePyodide;
  final Tester? tester;
  final bool multiView;
  final RufletBackendChannelBuilder? channelBuilder;

  const RufletApp(
      {super.key,
      required this.pageUrl,
      required this.assetsDir,
      this.assetsBundlePath,
      this.showAppStartupScreen,
      this.appStartupScreenMessage,
      this.appErrorMessage,
      this.controlId,
      this.title,
      this.errorsHandler,
      this.reconnectIntervalMs,
      this.reconnectTimeoutMs,
      this.extensions,
      this.args,
      this.forcePyodide,
      this.tester,
      this.channelBuilder,
      this.multiView = false});

  @override
  State<RufletApp> createState() => _RufletAppState();
}

class _RufletAppState extends State<RufletApp> {
  RufletBackend? backend;

  @override
  void deactivate() {
    backend?.dispose();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RufletBackend>(
      create: (context) {
        return RufletBackend(
            showAppStartupScreen: widget.showAppStartupScreen,
            appStartupScreenMessage: widget.appStartupScreenMessage,
            appErrorMessage: widget.appErrorMessage,
            controlId: widget.controlId,
            reconnectIntervalMs: widget.reconnectIntervalMs,
            reconnectTimeoutMs: widget.reconnectTimeoutMs,
            pageUri: Uri.parse(widget.pageUrl),
            assetsDir: widget.assetsDir,
            assetsBundlePath: widget.assetsBundlePath,
            errorsHandler: widget.errorsHandler,
            extensions: widget.extensions ?? [],
            args: widget.args,
            forcePyodide: widget.forcePyodide,
            tester: widget.tester,
            channelBuilder: widget.channelBuilder,
            multiView: widget.multiView,
            parentRufletBackend:
                Provider.of<RufletBackend?>(context, listen: false));
      },
      child: Selector<RufletBackend, Control>(
        selector: (_, backend) => backend.page,
        builder: (_, page, __) => ControlWidget(control: page),
      ),
    );
  }
}
