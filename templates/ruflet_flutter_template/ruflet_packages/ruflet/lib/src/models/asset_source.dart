class AssetSource {
  final String path;
  final bool isFile;
  final bool isAsset;

  const AssetSource(
      {required this.path, required this.isFile, this.isAsset = false})
      : assert(!isFile || !isAsset);

  @override
  String toString() {
    return 'AssetSource(path: $path, isFile: $isFile, isAsset: $isAsset)';
  }
}
