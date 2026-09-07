import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit_video/media_kit_video.dart';

class MaterialRufletVideoControls extends StatelessWidget with RufletStoreMixin {
  const MaterialRufletVideoControls({super.key, required this.state});

  final VideoState state;

  @override
  Widget build(BuildContext context) => withPagePlatform((context, platform) {
        return platform == TargetPlatform.android ||
                platform == TargetPlatform.fuchsia
            ? MaterialVideoControls(state)
            : MaterialDesktopVideoControls(state);
      });
}
