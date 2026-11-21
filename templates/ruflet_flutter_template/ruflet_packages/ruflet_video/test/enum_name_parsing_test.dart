import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:ruflet_video/src/utils/video.dart';

void main() {
  test('playlist mode names match in any letter case', () {
    expect(parsePlaylistMode('loop'), PlaylistMode.loop);
    expect(parsePlaylistMode('SINGLE'), PlaylistMode.single);
    expect(parsePlaylistMode('None'), PlaylistMode.none);
  });

  test('unknown or missing playlist modes keep the default', () {
    expect(parsePlaylistMode('shuffle', PlaylistMode.none), PlaylistMode.none);
    expect(parsePlaylistMode(null, PlaylistMode.loop), PlaylistMode.loop);
  });
}
