import 'package:ruflet_video/src/cupertino_video_controls.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, Theme;
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class _Player extends PlatformPlayer {
  _Player() : super(configuration: const PlayerConfiguration()) {
    state = state.copyWith(subtitle: ['Native subtitles']);
  }
}

class _VideoController implements VideoController {
  _VideoController(this.player);

  @override
  final Player player;
  @override
  final notifier = ValueNotifier<PlatformVideoController?>(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'subtitles and fullscreen never mount Material in Cupertino video',
      (tester) async {
    final player = Player(platformPlayer: _Player());
    final controller = _VideoController(player);
    var entered = 0;
    var exited = 0;
    await tester.pumpWidget(CupertinoApp(
        home: Video(
      controller: controller,
      wakelock: false,
      controls: (state) => CupertinoRufletVideoControls(state: state),
      onEnterFullscreen: () async {
        entered++;
      },
      onExitFullscreen: () async {
        exited++;
      },
    )));
    await tester.pump();
    expect(find.text('Native subtitles'), findsOneWidget);
    expect(find.byType(Material), findsNothing);
    expect(find.byType(Theme), findsNothing);
    await tester
        .tap(find.byIcon(CupertinoIcons.arrow_up_left_arrow_down_right));
    await tester.pumpAndSettle();
    expect(entered, 1);
    expect(find.text('Native subtitles'), findsOneWidget);
    expect(find.byType(Material), findsNothing);
    expect(find.byType(Theme), findsNothing);
    await tester
        .tap(find.byIcon(CupertinoIcons.arrow_down_right_arrow_up_left));
    await tester.pumpAndSettle();
    expect(exited, 1);
    expect(find.byType(Material), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await player.dispose();
    controller.notifier.dispose();
  });
}
