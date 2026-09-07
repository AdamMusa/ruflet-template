import 'package:ruflet/ruflet.dart';

import 'audio_recorder.dart';

class Extension extends RufletExtension {
  @override
  RufletService? createService(Control control) {
    switch (control.type) {
      case "AudioRecorder":
        return AudioRecorderService(control: control);
      default:
        return null;
    }
  }
}
