import 'dart:async';

import 'package:ruflet/ruflet.dart';
import 'package:ruflet_ads/ruflet_ads.dart' as ruflet_ads;
// --FAT_CLIENT_START--
import 'package:ruflet_audio/ruflet_audio.dart' as ruflet_audio;
// --FAT_CLIENT_END--
import 'package:ruflet_audio_recorder/ruflet_audio_recorder.dart'
    as ruflet_audio_recorder;
import 'package:ruflet_camera/ruflet_camera.dart' as ruflet_camera;
import 'package:ruflet_charts/ruflet_charts.dart' as ruflet_charts;
import 'package:ruflet_code_editor/ruflet_code_editor.dart' as ruflet_code_editor;
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
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'connection_probe.dart';
import 'package:ruflet_webview/ruflet_webview.dart' as ruflet_webview;

const bool isProduction = bool.fromEnvironment('dart.vm.product');
const int kRufletPort = 8550;
const String kConfiguredBackendUrl = String.fromEnvironment(
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

String fallbackBackendUrl() =>
    normalizePageUrlForPlatform('http://0.0.0.0:$kRufletPort');

/// A preview client is launched against whichever port the server happened to
/// bind, so the backend cannot be fixed at build time. Prefer the URL the
/// launcher passed on the command line, then the build-time value.
///
/// This file is the web entrypoint too, so it must not import dart:io — the
/// launcher passes the URL as an argument rather than in the environment.
String resolveBackendUrl([List<String>? args]) {
  if (args != null && args.isNotEmpty) {
    final fromArgs = parseBackendUrl(args.first);
    if (fromArgs != null) return fromArgs;
  }

  final configured = parseBackendUrl(kConfiguredBackendUrl);
  if (configured != null) return configured;

  // On the web the Ruflet backend serves this client itself, so the origin it
  // was loaded from is the backend. `ruflet run --web` binds an arbitrary port
  // and cannot bake a URL in at build time, and the web entrypoint receives no
  // launch arguments -- without this the client would fall through to the
  // default port and wait for a server that is not there.
  if (kIsWeb) {
    final origin = parseBackendUrl(Uri.base.origin);
    if (origin != null) return origin;
  }

  return fallbackBackendUrl();
}

Future<void> main([List<String>? args]) async {
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

  final pageUrl = resolveBackendUrl(args);
  await waitForBackend(pageUrl);

  runApp(TemplateApp(pageUrl: pageUrl, extensions: extensions));
}

class TemplateApp extends StatelessWidget {
  const TemplateApp({
    super.key,
    required this.pageUrl,
    required this.extensions,
  });

  final String pageUrl;
  final List<RufletExtension> extensions;

  @override
  Widget build(BuildContext context) {
    return RufletApp(
      title: 'Ruflet',
      pageUrl: pageUrl,
      assetsDir: '',
      errorsHandler: RufletAppErrorsHandler(),
      showAppStartupScreen: true,
      appStartupScreenMessage: 'Working...',
      appErrorMessage: 'The application encountered an error: {message}',
      extensions: extensions,
      multiView: isMultiView(),
      tester: tester,
    );
  }
}

Future<void> waitForBackend(String pageUrl) async {
  if (kIsWeb) return;

  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    if (await canConnectToPageUrl(pageUrl)) return;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  debugPrint('Backend not reachable yet at $pageUrl. Ruflet client will retry.');
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
