import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class CupertinoRufletVideoControls extends StatefulWidget {
  const CupertinoRufletVideoControls({super.key, required this.state});

  final VideoState state;

  @override
  State<CupertinoRufletVideoControls> createState() =>
      _CupertinoRufletVideoControlsState();
}

class _CupertinoRufletVideoControlsState
    extends State<CupertinoRufletVideoControls> {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final FocusNode _focus = FocusNode();
  Timer? _hideTimer;
  bool _visible = true;
  double _lastVolume = 100;
  String? _error;

  Player get _player => widget.state.widget.controller.player;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    for (final stream in <Stream<dynamic>>[
      _player.stream.playing,
      _player.stream.position,
      _player.stream.duration,
      _player.stream.volume,
      _player.stream.buffering,
      _player.stream.playlist,
      _player.stream.track,
      _player.stream.tracks,
      _player.stream.rate,
    ]) {
      _subscriptions.add(stream.listen((_) {
        if (mounted) setState(() {});
      }));
    }
    _subscriptions.add(_player.stream.error.listen((error) {
      if (mounted) setState(() => _error = error);
    }));
    _reveal();
  }

  @override
  void didUpdateWidget(CupertinoRufletVideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.widget.controller != widget.state.widget.controller) {
      for (final subscription in _subscriptions) {
        unawaited(subscription.cancel());
      }
      _subscriptions.clear();
      _error = null;
      _listen();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _focus.dispose();
    super.dispose();
  }

  void _reveal() {
    _hideTimer?.cancel();
    if (!_visible && mounted) setState(() => _visible = true);
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _player.state.playing && !_focus.hasFocus) {
        setState(() => _visible = false);
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    _reveal();
    try {
      await action();
      if (mounted && _error != null) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _mute() {
    final volume = _player.state.volume;
    if (volume > 0) _lastVolume = volume;
    unawaited(_run(() => _player.setVolume(volume > 0 ? 0 : _lastVolume)));
  }

  Future<void> _settings() async {
    _hideTimer?.cancel();
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('Playback'),
        actions: [
          for (final rate in [0.5, 1.0, 1.5, 2.0])
            CupertinoActionSheetAction(
              isDefaultAction: _player.state.rate == rate,
              onPressed: () {
                Navigator.pop(popupContext);
                unawaited(_run(() => _player.setRate(rate)));
              },
              child: Text('$rate× speed'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              unawaited(
                  _run(() => _player.setSubtitleTrack(SubtitleTrack.no())));
            },
            child: const Text('Subtitles off'),
          ),
          for (final track in _player.state.tracks.subtitle
              .where((track) => track.id != 'no'))
            CupertinoActionSheetAction(
              isDefaultAction: _player.state.track.subtitle == track,
              onPressed: () {
                Navigator.pop(popupContext);
                unawaited(_run(() => _player.setSubtitleTrack(track)));
              },
              child: Text(
                  track.title ?? track.language ?? 'Subtitles ${track.id}'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(popupContext),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (mounted) _reveal();
  }

  @override
  Widget build(BuildContext context) {
    final state = _player.state;
    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.space) {
          unawaited(_run(_player.playOrPause));
        } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
          _mute();
        } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
          unawaited(_run(() => toggleFullscreen(context)));
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowRight) {
          final offset =
              event.logicalKey == LogicalKeyboardKey.arrowLeft ? -10 : 10;
          final millis = (state.position + Duration(seconds: offset))
              .inMilliseconds
              .clamp(0, state.duration.inMilliseconds);
          unawaited(_run(() => _player.seek(Duration(milliseconds: millis))));
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: MouseRegion(
        onHover: (_) => _reveal(),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            _focus.requestFocus();
            _reveal();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (state.buffering)
                const Center(
                    child: CupertinoActivityIndicator(
                        color: CupertinoColors.white)),
              if (_visible || !state.playing)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: CupertinoVideoControlsView(
                    playing: state.playing,
                    position: state.position,
                    duration: state.duration,
                    volume: state.volume,
                    fullscreen: isFullscreen(context),
                    hasPlaylist: state.playlist.medias.length > 1,
                    error: _error,
                    onPlayPause: () => unawaited(_run(_player.playOrPause)),
                    onSeek: (position) =>
                        unawaited(_run(() => _player.seek(position))),
                    onVolume: (volume) =>
                        unawaited(_run(() => _player.setVolume(volume))),
                    onMute: _mute,
                    onPrevious: () => unawaited(_run(_player.previous)),
                    onNext: () => unawaited(_run(_player.next)),
                    onFullscreen: () =>
                        unawaited(_run(() => toggleFullscreen(context))),
                    onSettings: () => unawaited(_settings()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Native Cupertino chrome with callbacks shared by normal and fullscreen video.
class CupertinoVideoControlsView extends StatelessWidget {
  const CupertinoVideoControlsView({
    super.key,
    required this.playing,
    required this.position,
    required this.duration,
    required this.volume,
    required this.fullscreen,
    required this.hasPlaylist,
    required this.onPlayPause,
    required this.onSeek,
    required this.onVolume,
    required this.onMute,
    required this.onPrevious,
    required this.onNext,
    required this.onFullscreen,
    required this.onSettings,
    this.error,
  });

  final bool playing, fullscreen, hasPlaylist;
  final Duration position, duration;
  final double volume;
  final String? error;
  final VoidCallback onPlayPause,
      onMute,
      onPrevious,
      onNext,
      onFullscreen,
      onSettings;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<double> onVolume;

  String _time(Duration value) {
    final seconds = value.inSeconds.clamp(0, 359999);
    final minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Widget _button(String label, IconData icon, VoidCallback callback) =>
      Semantics(
        label: label,
        button: true,
        child: CupertinoButton(
          padding: const EdgeInsets.all(8),
          onPressed: callback,
          child: Icon(icon, color: CupertinoColors.white, size: 22),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds.toDouble();
    return ColoredBox(
      color: const Color(0xB3000000),
      child: SafeArea(
        top: false,
        child: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: CupertinoColors.white,
                fontSize: 12,
              ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null)
                  Text(error!, maxLines: 2, overflow: TextOverflow.ellipsis),
                Row(children: [
                  Text(_time(position)),
                  Expanded(
                    child: Semantics(
                      label: 'Video position',
                      child: CupertinoSlider(
                        value: position.inMilliseconds
                            .toDouble()
                            .clamp(0, total > 0 ? total : 1),
                        max: total > 0 ? total : 1,
                        onChanged: total > 0
                            ? (value) =>
                                onSeek(Duration(milliseconds: value.round()))
                            : null,
                      ),
                    ),
                  ),
                  Text(_time(duration)),
                ]),
                LayoutBuilder(
                    builder: (context, constraints) => Row(children: [
                          if (hasPlaylist && constraints.maxWidth >= 320)
                            _button('Previous video',
                                CupertinoIcons.backward_end_fill, onPrevious),
                          _button(
                              playing ? 'Pause' : 'Play',
                              playing
                                  ? CupertinoIcons.pause_fill
                                  : CupertinoIcons.play_fill,
                              onPlayPause),
                          if (hasPlaylist && constraints.maxWidth >= 320)
                            _button('Next video',
                                CupertinoIcons.forward_end_fill, onNext),
                          _button(
                              volume == 0 ? 'Unmute' : 'Mute',
                              volume == 0
                                  ? CupertinoIcons.speaker_slash_fill
                                  : CupertinoIcons.speaker_2_fill,
                              onMute),
                          if (constraints.maxWidth >= 480)
                            SizedBox(
                                width: 100,
                                child: Semantics(
                                  label: 'Volume',
                                  child: CupertinoSlider(
                                      value: volume.clamp(0, 100),
                                      max: 100,
                                      onChanged: onVolume),
                                )),
                          const Spacer(),
                          _button('Playback settings',
                              CupertinoIcons.ellipsis_circle, onSettings),
                          _button(
                              fullscreen
                                  ? 'Exit fullscreen'
                                  : 'Enter fullscreen',
                              fullscreen
                                  ? CupertinoIcons
                                      .arrow_down_right_arrow_up_left
                                  : CupertinoIcons
                                      .arrow_up_left_arrow_down_right,
                              onFullscreen),
                        ])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
