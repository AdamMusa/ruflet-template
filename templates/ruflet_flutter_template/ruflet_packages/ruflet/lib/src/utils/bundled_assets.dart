import 'package:path/path.dart' as p;

import '../models/asset_source.dart';

AssetSource? bundledAssetSource(String src, String? assetsBundlePath) {
  if (assetsBundlePath == null || assetsBundlePath.isEmpty) return null;
  final uri = Uri.parse(src);
  if (uri.hasScheme || uri.hasAuthority) return null;
  var relative =
      uri.path.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
  // Ruby accepts both "logo.png" and "assets/logo.png" relative to the
  // project's assets directory. Bundle keys are POSIX on every host platform.
  if (relative.startsWith('assets/')) relative = relative.substring(7);
  relative = p.posix.normalize(relative);
  if (relative == '..' || relative.startsWith('../')) {
    throw ArgumentError.value(
        src, 'src', 'Asset escapes the project assets directory');
  }
  return AssetSource(
      path: p.posix.join(assetsBundlePath, relative),
      isFile: false,
      isAsset: true);
}
