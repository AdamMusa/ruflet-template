import 'package:flutter/widgets.dart';

import '../ruflet_app.dart';
import '../ruflet_app_errors_handler.dart';
import '../ruflet_backend.dart';
import '../models/control.dart';
import '../utils/numbers.dart';
import 'base_controls.dart';

class RufletAppControl extends StatefulWidget {
  final Control control;

  RufletAppControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<RufletAppControl> createState() => _RufletAppControlState();
}

class _RufletAppControlState extends State<RufletAppControl> {
  final _errorsHandler = RufletAppErrorsHandler();

  @override
  Widget build(BuildContext context) {
    debugPrint("RufletApp build: ${widget.control.id}");

    var url = widget.control.getString("url", "")!;
    var reconnectIntervalMs = widget.control.getInt("reconnect_interval_ms");
    var reconnectTimeoutMs = widget.control.getInt("reconnect_timeout_ms");
    var showAppStartupScreen =
        widget.control.getBool("show_app_startup_screen");
    var appStartupScreenMessage =
        widget.control.getString("app_startup_screen_message");
    var appErrorMessage = widget.control.getString("app_error_message");

    return LayoutControl(
      control: widget.control,
      child: RufletApp(
        controlId: widget.control.id,
        reconnectIntervalMs: reconnectIntervalMs,
        reconnectTimeoutMs: reconnectTimeoutMs,
        showAppStartupScreen: showAppStartupScreen,
        appStartupScreenMessage: appStartupScreenMessage,
        appErrorMessage: appErrorMessage,
        pageUrl: url,
        assetsDir: "",
        errorsHandler: _errorsHandler,
        extensions: RufletBackend.of(context).extensions,
        args: widget.control.get("args") != null
            ? Map<String, dynamic>.from(widget.control.get("args"))
            : null,
        forcePyodide: widget.control.getBool("force_pyodide"),
      ),
    );
  }
}
