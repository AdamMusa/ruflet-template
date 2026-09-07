import 'package:flutter/widgets.dart';
import 'package:flutter_svg/svg.dart';

import '../models/asset_source.dart';
import 'bundled_assets.dart';

SvgPicture getSvgPictureFromFile(
    {required String src,
    required double? width,
    required double? height,
    required BoxFit fit,
    required Color? color,
    required BlendMode blendMode,
    required String? semanticsLabel}) {
  return SvgPicture.string("<svg/>");
}

AssetSource getAssetSrc(String src, Uri pageUri, String assetsDir,
    {String? assetsBundlePath}) {
  final bundled = bundledAssetSource(src, assetsBundlePath);
  if (bundled != null) return bundled;
  return AssetSource(
      path: src.startsWith("/") ? src.substring(1) : src, isFile: false);
}

ImageProvider getFileImageProvider(String path) {
  throw UnimplementedError();
}
