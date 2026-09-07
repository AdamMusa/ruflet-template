import 'dart:convert';

import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Assets extends CachingAssetBundle {
  final loaded = <String>[];
  @override
  Future<ByteData> load(String key) async {
    loaded.add(key);
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, dynamic>{})!;
    }
    if (key == 'assets/demo/assets/icon.png') {
      return ByteData.sublistView(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR1EAAAAASUVORK5CYII='));
    }
    throw StateError('Unexpected asset: $key');
  }
}

void main() {
  test('in-process project assets use bundle keys, explicit URLs stay remote',
      () {
    final backend = RufletBackend(
        pageUri: Uri.parse('inprocess://embedded'),
        assetsDir: '',
        assetsBundlePath: 'assets/demo/assets',
        extensions: [],
        multiView: false);
    for (final src in ['icon.png', 'assets/icon.png', '/assets/icon.png']) {
      final asset = backend.getAssetSource(src);
      expect(asset.path, 'assets/demo/assets/icon.png');
      expect(asset.isAsset, isTrue);
      expect(asset.isFile, isFalse);
    }
    final remote = backend.getAssetSource('http://192.168.1.227:8550/icon.png');
    expect(remote.isAsset, isFalse);
    expect(remote.path, 'http://192.168.1.227:8550/icon.png');
    expect(() => backend.getAssetSource('../secret'), throwsArgumentError);
    final preview = RufletBackend(
        pageUri: Uri.parse('http://192.168.1.227:8550'),
        assetsDir: '',
        extensions: [],
        multiView: false);
    expect(preview.getAssetSource('assets/icon.png').isAsset, isFalse);
    expect(
        preview.getAssetSource('assets/icon.png').path, startsWith('http://'));
  });

  testWidgets('bundled logo renders with the exact Ruby image size',
      (tester) async {
    final assets = _Assets();
    final backend = RufletBackend(
        pageUri: Uri.parse('inprocess://embedded'),
        assetsDir: '',
        assetsBundlePath: 'assets/demo/assets',
        extensions: [],
        multiView: false)
      ..platform = TargetPlatform.iOS;
    final control = Control.fromMap({
      '_c': 'Image',
      '_i': 10,
      'src': 'assets/icon.png',
      'width': 28,
      'height': 28
    }, backend);
    await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: DefaultAssetBundle(
          bundle: assets,
          child: CupertinoApp(
              home: Center(child: ControlWidget(control: control)))),
    ));
    await tester.pumpAndSettle();
    expect(assets.loaded, contains('assets/demo/assets/icon.png'));
    expect(tester.widget<Image>(find.byType(Image)).image, isA<AssetImage>());
    expect(tester.getSize(find.byType(Image)), const Size(28, 28));
    expect(tester.takeException(), isNull);
  });
}
