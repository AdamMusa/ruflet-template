import 'package:ruflet_video/src/cupertino_video_controls.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, Slider, IconButton;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Cupertino playback, seek, volume and fullscreen preserve callbacks',
      (tester) async {
    var play = 0;
    var fullscreen = 0;
    var previous = 0;
    var next = 0;
    var settings = 0;
    Duration? seek;
    double? volume;
    await tester.pumpWidget(CupertinoApp(
      home: Align(
        alignment: Alignment.bottomCenter,
        child: CupertinoVideoControlsView(
          playing: false,
          position: const Duration(seconds: 10),
          duration: const Duration(minutes: 2),
          volume: 50,
          fullscreen: false,
          hasPlaylist: true,
          onPlayPause: () => play++,
          onSeek: (value) => seek = value,
          onVolume: (value) => volume = value,
          onMute: () {},
          onPrevious: () => previous++,
          onNext: () => next++,
          onFullscreen: () => fullscreen++,
          onSettings: () => settings++,
        ),
      ),
    ));
    expect(find.byType(Material), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    await tester.tap(find.byIcon(CupertinoIcons.play_fill));
    await tester.tap(find.byIcon(CupertinoIcons.backward_end_fill));
    await tester.tap(find.byIcon(CupertinoIcons.forward_end_fill));
    await tester.tap(find.byIcon(CupertinoIcons.ellipsis_circle));
    await tester
        .tap(find.byIcon(CupertinoIcons.arrow_up_left_arrow_down_right));
    expect([play, previous, next, settings, fullscreen], [1, 1, 1, 1, 1]);
    final sliders = tester
        .widgetList<CupertinoSlider>(find.byType(CupertinoSlider))
        .toList();
    sliders.first.onChanged!(30000);
    sliders.last.onChanged!(75);
    expect(seek, const Duration(seconds: 30));
    expect(volume, 75);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown duration disables seeking and narrow controls fit',
      (tester) async {
    await tester.pumpWidget(CupertinoApp(
        home: Center(
            child: SizedBox(
      width: 240,
      child: CupertinoVideoControlsView(
        playing: true,
        position: Duration.zero,
        duration: Duration.zero,
        volume: 0,
        fullscreen: true,
        hasPlaylist: true,
        onPlayPause: () {},
        onSeek: (_) {},
        onVolume: (_) {},
        onMute: () {},
        onPrevious: () {},
        onNext: () {},
        onFullscreen: () {},
        onSettings: () {},
      ),
    ))));
    expect(
        tester.widget<CupertinoSlider>(find.byType(CupertinoSlider)).onChanged,
        isNull);
    expect(find.byIcon(CupertinoIcons.pause_fill), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.speaker_slash_fill), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
