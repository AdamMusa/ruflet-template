import 'dart:async';

import 'package:ruflet/ruflet.dart';
import 'package:ruflet_ads/ruflet_ads.dart' as ruflet_ads;
import 'package:ruflet/src/widgets/platform_startup_app.dart';
// --FAT_CLIENT_START--
import 'package:ruflet_audio/ruflet_audio.dart' as ruflet_audio;
// --FAT_CLIENT_END--
import 'package:ruflet_audio_recorder/ruflet_audio_recorder.dart'
    as ruflet_audio_recorder;
import 'package:ruflet_camera/ruflet_camera.dart' as ruflet_camera;
import 'package:ruflet_charts/ruflet_charts.dart' as ruflet_charts;
import 'package:ruflet_code_editor/ruflet_code_editor.dart'
    as ruflet_code_editor;
import 'package:ruflet_color_pickers/ruflet_color_pickers.dart'
    as ruflet_color_picker;
import 'package:ruflet_datatable2/ruflet_datatable2.dart' as ruflet_datatable2;
import 'package:ruflet_flashlight/ruflet_flashlight.dart' as ruflet_flashlight;
import 'package:ruflet_geolocator/ruflet_geolocator.dart' as ruflet_geolocator;
import 'package:ruflet_lottie/ruflet_lottie.dart' as ruflet_lottie;
import 'package:ruflet_map/ruflet_map.dart' as ruflet_map;
import 'package:ruflet_permission_handler/ruflet_permission_handler.dart'
    as ruflet_permission_handler;
import 'package:ruflet_rive/ruflet_rive.dart' as ruflet_rive;
// --FAT_CLIENT_START--
// --FAT_CLIENT_END--
import 'package:ruflet_secure_storage/ruflet_secure_storage.dart'
    as ruflet_secure_storage;
import 'package:ruflet_spinkit/ruflet_spinkit.dart' as ruflet_spinkit;
// --FAT_CLIENT_START--
import 'package:ruflet_video/ruflet_video.dart' as ruflet_video;
// --FAT_CLIENT_END--
import 'package:ruflet_qrcode_scanner/ruflet_qrcode_scanner.dart'
    as ruflet_qrcode_scanner;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:ruby_runtime/ruflet_runtime.dart';

import 'package:ruflet_webview/ruflet_webview.dart' as ruflet_webview;

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
    final routeUrlStrategy = getRufletRouteUrlStrategy();
    if (routeUrlStrategy == 'path') {
      usePathUrlStrategy();
    }
  }

  final extensions = <RufletExtension>[
    ruflet_ads.Extension(),
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

  // Empty for an ordinary self-contained build, which is what makes
  // TemplateApp ask the platform for the embedded transport instead.
  final pageUrl = resolveBackendUrl();

  // The embedded runtime is deliberately not awaited here. Platforms that can
  // start the VM before the Flutter engine exists have already been booting it
  // while these extensions initialized. TemplateApp resolves its transport
  // endpoint from the widget tree and shows a splash until it arrives.
  runApp(TemplateApp(pageUrl: pageUrl, extensions: extensions));
}

class TemplateApp extends StatefulWidget {
  const TemplateApp({
    super.key,
    required this.pageUrl,
    required this.extensions,
  });

  final String pageUrl;
  final List<RufletExtension> extensions;

  @override
  State<TemplateApp> createState() => _TemplateAppState();
}

class _TemplateAppState extends State<TemplateApp> {
  Timer? _runtimeErrorPoller;
  String? _lastRuntimeError;
  String _pageUrl = '';
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _pageUrl = widget.pageUrl;
    if (_pageUrl.isEmpty && !kIsWeb) {
      unawaited(_resolveEmbeddedTransport());
    }
  }

  /// Asks the platform for the runtime transport it started.
  ///
  /// The runtime is entirely the platform layer's concern: it locates the
  /// packaged project, unpacks it if the platform needs that, sets the
  /// runtime's environment, and starts the VM. Flutter only needs the endpoint
  /// used to select the matching Ruflet channel.
  Future<void> _resolveEmbeddedTransport() async {
    try {
      final url = await RufletRuntime.serverUrl();
      if (!mounted) return;
      // Used as-is. An embedded in-process endpoint is not a network address
      // and must never pass through host rewriting.
      setState(() => _pageUrl = url.toString());
      _watchForRuntimeErrors();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _startupError = 'Failed to start embedded Ruflet.\n$error',
      );
    }
  }

  void _watchForRuntimeErrors() {
    _runtimeErrorPoller = Timer.periodic(const Duration(seconds: 1), (_) async {
      final status = await RufletRuntime.status();
      final runtimeError = status.error;
      if (!mounted ||
          runtimeError.isEmpty ||
          runtimeError == _lastRuntimeError) {
        return;
      }
      _lastRuntimeError = runtimeError;
      debugPrint('Embedded runtime error: $runtimeError');
    });
  }

  @override
  void dispose() {
    _runtimeErrorPoller?.cancel();
    unawaited(RufletRuntime.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _startupError;
    if (error != null) {
      return PlatformStartupApp(
        title: 'Ruflet',
        isLoading: false,
        message: error,
      );
    }

    if (_pageUrl.isEmpty) {
      // RufletApp cannot be built without a URL, and the runtime has not reported
      // one yet. Hold a splash rather than delay startup waiting for it.
      return const PlatformStartupApp(title: 'Ruflet');
    }

    return RufletApp(
      title: 'Ruflet',
      pageUrl: _pageUrl,
      assetsDir: '',
      assetsBundlePath: _pageUrl.startsWith('inprocess://')
          ? 'assets/${const String.fromEnvironment('RUFLET_EMBEDDED_PROJECT')}/assets'
          : null,
      errorsHandler: RufletAppErrorsHandler(),
      showAppStartupScreen: true,
      appStartupScreenMessage: 'Working...',
      appErrorMessage: 'The application encountered an error: {message}',
      extensions: widget.extensions,
      multiView: isMultiView(),
      tester: tester,
      channelBuilder: _pageUrl.startsWith('inprocess://')
          ? ({
              required address,
              required args,
              required forcePyodide,
              required onDisconnect,
              required onMessage,
            }) => RufletInProcessBackendChannel(
              sendBytes: RufletRuntime.sendToRuby,
              receiveBytes: RufletRuntime.receiveFromRuby,
              closeBytes: RufletRuntime.closeBridge,
              onDisconnect: onDisconnect,
              onMessage: onMessage,
            )
          : null,
    );
  }
}

String? parseBackendUrl(String value) {
  if (value.isEmpty) return null;
  final raw = value.trim();
  final uri = Uri.tryParse(raw);
  if (uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty) {
    return normalizePageUrlForPlatform(raw);
  }
  final match = RegExp(r'(https?:\/\/[^\s]+)').firstMatch(raw);
  if (match == null) return null;
  return normalizePageUrlForPlatform(match.group(0)!);
}
