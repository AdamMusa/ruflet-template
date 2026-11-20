import 'package:ruflet/ruflet.dart';
import 'package:record/record.dart';

AudioEncoder? parseAudioEncoder(String? value, [AudioEncoder? defaultValue]) {
  if (value == null) return defaultValue;
  return parseEnum(AudioEncoder.values, value, defaultValue);
}

/// The name Ruby uses for an encoder: `aac_lc` for [AudioEncoder.aacLc].
String rubyEncoderName(AudioEncoder encoder) => encoder.name
    .replaceAllMapped(RegExp("[A-Z]"), (m) => "_${m[0]!.toLowerCase()}");

/// The input device to record from: a map with an "id" (and optional
/// "label"), or just the id, i.e. a key of the get_input_devices result.
/// A value that names no device, or whose id is blank, is an error, not the
/// default input. A map with a text "id" and "label" is passed on as before.
InputDevice? parseInputDevice(dynamic value, [InputDevice? defaultValue]) {
  if (value == null) return defaultValue;
  if (value is Map && value["id"] is String && value["label"] is String) {
    return InputDevice(id: value["id"], label: value["label"]);
  }
  final id = value is Map ? value["id"] : value;
  if ((id is String && id.trim().isNotEmpty) || id is num) {
    return InputDevice(
        id: id.toString(),
        label: value is Map ? value["label"]?.toString() ?? "" : "");
  }
  throw ArgumentError('AudioRecorder.start_recording: "device" must be a '
      'device id from get_input_devices or a map with an "id", got '
      '${value is String ? '"$value"' : value}');
}

AndroidAudioSource? parseAndroidAudioSource(String? value,
    [AndroidAudioSource? defaultValue]) {
  if (value == null) return defaultValue;
  return parseEnum(AndroidAudioSource.values, value, defaultValue);
}

AndroidRecordConfig? parseAndroidRecordConfig(dynamic value,
    [AndroidRecordConfig? defaultValue]) {
  if (value == null) return defaultValue;
  return AndroidRecordConfig(
      audioSource: parseAndroidAudioSource(
          value["audio_source"], AndroidAudioSource.defaultSource)!,
      manageBluetooth: parseBool(value["manage_bluetooth"], true)!,
      muteAudio: parseBool(value["mute_audio"], false)!,
      useLegacy: parseBool(value["use_legacy"], false)!);
}

IosAudioCategoryOption? parseIosAudioCategoryOption(String? value,
    [IosAudioCategoryOption? defaultValue]) {
  if (value == null) return defaultValue;
  return parseEnum(IosAudioCategoryOption.values, value, defaultValue);
}

/// The iOS category options: a list of option names. Without one the
/// recorder keeps record's default categories. Unknown names and nil entries
/// are dropped, as before; anything else is an error.
List<IosAudioCategoryOption> parseIosAudioCategoryOptions(dynamic value) {
  if (value == null) return const IosRecordConfig().categoryOptions;
  if (value is! List || value.any((o) => o != null && o is! String)) {
    throw ArgumentError('AudioRecorder.start_recording: "options" in '
        '"ios_configuration" must be a list of category option names, got '
        '${value is String ? '"$value"' : value}');
  }
  return value
      .map((o) => parseIosAudioCategoryOption(o as String?))
      .nonNulls
      .toList();
}

IosRecordConfig? parseIosRecordConfig(dynamic value,
    [IosRecordConfig? defaultValue]) {
  if (value == null) return defaultValue;
  return IosRecordConfig(
    // Moving to AudioRecorder.ios.manageAudioSession changes behavior.
    // ignore: deprecated_member_use
    manageAudioSession: parseBool(value["manage_audio_session"], true)!,
    categoryOptions: parseIosAudioCategoryOptions(value["options"]),
  );
}

RecordConfig? parseRecordConfig(dynamic value, [RecordConfig? defaultValue]) {
  if (value == null) return defaultValue;
  return RecordConfig(
    autoGain: parseBool(value["auto_gain"], false)!,
    bitRate: parseInt(value["bit_rate"], 128000)!,
    encoder: parseAudioEncoder(value["encoder"], AudioEncoder.wav)!,
    echoCancel: parseBool(value["cancel_echo"], false)!,
    noiseSuppress: parseBool(value["suppress_noise"], false)!,
    numChannels: parseInt(value["channels"], 2)!,
    device: parseInputDevice(value["device"]),
    sampleRate: parseInt(value["sample_rate"], 44100)!,
    androidConfig: parseAndroidRecordConfig(
        value["android_configuration"], const AndroidRecordConfig())!,
    iosConfig: parseIosRecordConfig(
        value["ios_configuration"], const IosRecordConfig())!,
  );
}
