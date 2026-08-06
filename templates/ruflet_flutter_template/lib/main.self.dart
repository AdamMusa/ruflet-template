import 'dart:async';

import 'package:flet/flet.dart';
// --FAT_CLIENT_START--
import 'package:flet_audio/flet_audio.dart' as ruflet_audio;
// --FAT_CLIENT_END--
import 'package:flet_audio_recorder/flet_audio_recorder.dart'
    as ruflet_audio_recorder;
import 'package:flet_camera/flet_camera.dart' as ruflet_camera;
import 'package:flet_charts/flet_charts.dart' as ruflet_charts;
import 'package:flet_code_editor/flet_code_editor.dart' as ruflet_code_editor;
import 'package:flet_color_pickers/flet_color_pickers.dart'
    as ruflet_color_picker;
import 'package:flet_datatable2/flet_datatable2.dart' as ruflet_datatable2;
import 'package:flet_flashlight/flet_flashlight.dart' as ruflet_flashlight;
import 'package:flet_geolocator/flet_geolocator.dart' as ruflet_geolocator;
import 'package:flet_lottie/flet_lottie.dart' as ruflet_lottie;
import 'package:flet_map/flet_map.dart' as ruflet_map;
import 'package:flet_permission_handler/flet_permission_handler.dart'
    as ruflet_permission_handler;
import 'package:flet_rive/flet_rive.dart' as ruflet_rive;
// --FAT_CLIENT_START--
// --FAT_CLIENT_END--
import 'package:flet_secure_storage/flet_secure_storage.dart'
    as ruflet_secure_storage;
import 'package:flet_spinkit/flet_spinkit.dart' as ruflet_spinkit;
// --FAT_CLIENT_START--
import 'package:flet_video/flet_video.dart' as ruflet_video;
// --FAT_CLIENT_END--
import 'package:ruflet_qrcode_scanner/ruflet_qrcode_scanner.dart'
    as ruflet_qrcode_scanner;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:ruby_runtime/ruflet_runtime.dart';

import 'package:flet_webview/flet_webview.dart' as ruflet_webview;

const bool isProduction = bool.fromEnvironment('dart.vm.product');
const String kConfiguredClientUrl = String.fromEnvironment(
  'RUFLET_BACKEND_URL',
  defaultValue: String.fromEnvironment('RUFLET_CLIENT_URL', defaultValue: ''),
);
Tester? tester;

String normalizePageUrlForPlatform(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  if (uri == null || uri.host.isEmpty) return rawUrl;

  final localHosts = {
    '0.0.0.0',
    '::',
    '[::]',
    '127.0.0.1',
    'localhost',
    '::1',
    '[::1]',
  };
  if (!localHosts.contains(uri.host)) {
    return rawUrl;
  }

  String host;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      host = '10.0.2.2';
      break;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      host = 'localhost';
      break;
  }

  return uri.replace(host: host).toString();
}

String resolveBackendUrl() {
  final configured = parseBackendUrl(kConfiguredClientUrl);
  if (configured != null) return configured;
  return '';
}

Future<void> main() async {
  if (isProduction) {
    // ignore: avoid_returning_null_for_void
    debugPrint = (String? message, {int? wrapWidth}) => null;
  }

  await setupDesktop();
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    final routeUrlStrategy = getFletRouteUrlStrategy();
    if (routeUrlStrategy == 'path') {
      usePathUrlStrategy();
    }
  }

  final extensions = <FletExtension>[
    ruflet_spinkit.Extension(),
    ruflet_audio_recorder.Extension(),
    ruflet_camera.Extension(),
    ruflet_charts.Extension(),
    ruflet_code_editor.Extension(),
    ruflet_color_picker.Extension(),
    ruflet_datatable2.Extension(),
    ruflet_flashlight.Extension(),
    ruflet_geolocator.Extension(),
    ruflet_lottie.Extension(),
    ruflet_map.Extension(),
    ruflet_permission_handler.Extension(),
    ruflet_rive.Extension(),
    ruflet_secure_storage.Extension(),
    ruflet_webview.Extension(),
    ruflet_qrcode_scanner.Extension(),

    // --FAT_CLIENT_START--
    ruflet_audio.Extension(),
    ruflet_video.Extension(),
    // --FAT_CLIENT_END--
  ];

  for (final extension in extensions) {
    extension.ensureInitialized();
  }

  // The embedded runtime is deliberately not awaited here. Platforms that can
  // start the VM before the Flutter engine exists have already been booting it
  // while these extensions initialized, and blocking startup on it would hand
  // back exactly the time that parallelism buys. TemplateApp resolves the URL
  // from the widget tree and shows a splash until it arrives.
  runApp(
    TemplateApp(
      pageUrl: resolveBackendUrl(),
      extensions: extensions,
    ),
  );
}

class TemplateApp extends StatefulWidget {
  const TemplateApp({
    super.key,
    required this.pageUrl,
    required this.extensions,
  });

  final String pageUrl;
  final List<FletExtension> extensions;

  @override
  State<TemplateApp> createState() => _TemplateAppState();
}

class _TemplateAppState extends State<TemplateApp> {
  Timer? _serverErrorPoller;
  String? _lastEmbeddedServerError;
  String _pageUrl = '';
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _pageUrl = widget.pageUrl;
    if (_pageUrl.isEmpty && !kIsWeb) {
      unawaited(_resolveEmbeddedServer());
    }
  }

  /// Asks the platform where the runtime it started ended up.
  ///
  /// The runtime is entirely the platform layer's concern: it locates the
  /// packaged project, unpacks it if the platform needs that, sets the
  /// runtime's environment, starts the VM and waits for the port. None of that
  /// belongs in Flutter, which only needs the address to point FletApp at.
  Future<void> _resolveEmbeddedServer() async {
    try {
      final url = await RufletRuntime.serverUrl();
      if (!mounted) return;
      // Used as-is, deliberately. normalizePageUrlForPlatform rewrites
      // 127.0.0.1 to 10.0.2.2 on Android, which is the emulator's alias for the
      // host machine — right for a development server, wrong for an embedded
      // one running on the device itself.
      setState(() => _pageUrl = url.toString());
      _watchForServerErrors();
    } catch (error) {
      if (!mounted) return;
      setState(() => _startupError = 'Failed to start embedded Ruflet.\n$error');
    }
  }

  void _watchForServerErrors() {
    _serverErrorPoller = Timer.periodic(const Duration(seconds: 1), (_) async {
      final status = await RufletRuntime.status();
      final serverError = status.error;
      if (!mounted ||
          serverError.isEmpty ||
          serverError == _lastEmbeddedServerError) {
        return;
      }
      _lastEmbeddedServerError = serverError;
      debugPrint('Embedded server error: $serverError');
    });
  }

  @override
  void dispose() {
    _serverErrorPoller?.cancel();
    unawaited(RufletRuntime.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _startupError;
    if (error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(title: const Text('Ruflet')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(error),
          ),
        ),
      );
    }

    if (_pageUrl.isEmpty) {
      // FletApp cannot be built without a URL, and the runtime has not reported
      // one yet. Hold a splash rather than delay startup waiting for it.
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return FletApp(
      title: 'Ruflet',
      pageUrl: _pageUrl,
      assetsDir: '',
      errorsHandler: FletAppErrorsHandler(),
      showAppStartupScreen: true,
      appStartupScreenMessage: 'Working...',
      appErrorMessage: 'The application encountered an error: {message}',
      extensions: widget.extensions,
      multiView: isMultiView(),
      tester: tester,
    );
  }
}

String? parseBackendUrl(String value) {
  if (value.isEmpty) return null;
  final raw = value.trim();
  final uri = Uri.tryParse(raw);
  if (uri != null &&
      (uri.scheme == 'http' ||
          uri.scheme == 'https' ||
          uri.scheme == 'ws' ||
          uri.scheme == 'wss') &&
      uri.host.isNotEmpty) {
    return normalizePageUrlForPlatform(raw);
  }
  final match = RegExp(r'(https?:\/\/[^\s]+|wss?:\/\/[^\s]+)').firstMatch(raw);
  if (match == null) return null;
  return normalizePageUrlForPlatform(match.group(0)!);
}

