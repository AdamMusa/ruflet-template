import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _nativeRendererChannel = MethodChannel(
  'ruflet/native_renderer',
);
const bool _nativeAppleRendererEnabled = bool.fromEnvironment(
  'RUFLET_EXPERIMENTAL_NATIVE_RENDERER',
  defaultValue: false,
);

/// Whether this Flutter entrypoint should hand its resolved Ruflet session to
/// the native Apple renderer.
///
/// Dart owns this choice so self-contained and server-driven builds follow the
/// ordinary Flutter startup pipeline first. Other platforms never call the
/// native bridge and continue rendering through the Ruflet Flutter engine.
bool get usesNativeAppleRenderer {
  if (kIsWeb || !_nativeAppleRendererEnabled) return false;
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

/// Hands an Apple session to Swift or fails startup explicitly.
///
/// Explicit experimental Apple builds have no Flutter renderer fallback. A failed
/// handoff is an integration error that must remain visible instead of
/// silently switching engines and hiding a missing native capability.
Future<void> requireNativeAppleRenderer(String pageUrl) async {
  if (!usesNativeAppleRenderer) {
    throw StateError('The native Apple renderer was required off Apple.');
  }
  if (pageUrl.isEmpty) {
    throw StateError('The native Apple renderer requires a Ruflet page URL.');
  }
  if (!await showNativeAppleRenderer(pageUrl)) {
    throw StateError('The Apple host did not present the native renderer.');
  }
}
