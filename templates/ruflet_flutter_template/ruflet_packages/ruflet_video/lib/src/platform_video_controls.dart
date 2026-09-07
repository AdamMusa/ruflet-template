import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'cupertino_video_controls.dart';
import 'material_video_controls.dart';

/// Playback and protocol events stay on VideoControl's shared player.
Widget platformVideoControls(VideoState state) => PlatformControlRenderer(
      material: (_) => MaterialRufletVideoControls(state: state),
      cupertino: (_) => CupertinoRufletVideoControls(state: state),
    );
