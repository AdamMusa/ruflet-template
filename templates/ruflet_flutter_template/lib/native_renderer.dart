import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _nativeRendererChannel = MethodChannel(
  'ruflet/native_renderer',
);

/// Whether this Flutter entrypoint should hand its resolved Ruflet session to
/// the native Apple renderer.
///
/// Dart owns this choice so self-contained and server-driven builds follow the
/// ordinary Flutter startup pipeline first. Other platforms never call the
/// native bridge and continue rendering through Flet's Flutter client.
bool get usesNativeAppleRenderer {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

/// Replaces only the visible Apple renderer while leaving Flutter and its
/// plugins alive. The same resolved page URL is used by both renderers.
Future<bool> showNativeAppleRenderer(String pageUrl) async {
  if (!usesNativeAppleRenderer) return false;
  return await _nativeRendererChannel.invokeMethod<bool>('show', {
        'pageUrl': pageUrl,
      }) ??
      false;
}
