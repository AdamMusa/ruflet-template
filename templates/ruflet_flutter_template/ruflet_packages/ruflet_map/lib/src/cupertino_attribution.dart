import 'dart:async';

import 'package:ruflet/ruflet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';

import 'utils/attribution_alignment.dart';

class CupertinoSimpleAttribution extends StatelessWidget {
  const CupertinoSimpleAttribution({super.key, required this.control});

  final Control control;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Align(
          alignment: control.getAlignment('alignment', Alignment.bottomRight)!,
          child: ColoredBox(
            color: control.getColor('bgcolor', context,
                CupertinoColors.systemBackground.resolveFrom(context))!,
            child: CupertinoButton(
              padding: const EdgeInsets.all(3),
              onPressed: () => control.triggerEvent('click'),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('flutter_map | © '),
                control.buildTextOrWidget('text') ??
                    const Text('Placeholder Text'),
              ]),
            ),
          ),
        ),
      );
}

class CupertinoRichAttribution extends StatelessWidget {
  const CupertinoRichAttribution({super.key, required this.control});

  final Control control;

  @override
  Widget build(BuildContext context) {
    final texts = <Widget>[];
    final logos = <Widget>[];
    for (final item in control.children('attributions')) {
      item.notifyParent = true;
      if (item.type == 'TextSourceAttribution') {
        texts.add(CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 4),
          onPressed: () => item.triggerEvent('click'),
          child: Text(
            '${item.getBool('prepend_copyright', true)! ? '© ' : ''}'
            '${item.getString('text', 'Placeholder Text')!}',
            style: item.getTextStyle('text_style', RufletStyleTheme.of(context)),
          ),
        ));
      } else if (item.type == 'ImageSourceAttribution') {
        final image = item.buildWidget('image');
        if (image == null) continue;
        logos.add(Semantics(
          label: item.getString('tooltip'),
          button: true,
          child: CupertinoButton(
            padding: const EdgeInsets.all(3),
            onPressed: () => item.triggerEvent('click'),
            child:
                SizedBox(height: item.getDouble('height', 24)!, child: image),
          ),
        ));
      }
    }
    final height = control.getDouble('permanent_height', 24)!;
    if (control.getBool('show_flutter_map_attribution', true)!) {
      logos.add(Semantics(
        label: 'flutter_map',
        image: true,
        child: SizedBox(
          height: height,
          child: Image.asset('lib/assets/flutter_map_logo.png',
              package: 'flutter_map'),
        ),
      ));
      texts.add(const Text("Made with 'flutter_map'",
          style: TextStyle(fontStyle: FontStyle.italic)));
    }
    return CupertinoMapAttribution(
      attributions: texts,
      logos: logos,
      permanentHeight: height,
      alignment: parseAttributionAlignment(
              control.getString('alignment'), AttributionAlignment.bottomRight)!
          .real,
      backgroundColor: control.getColor('popup_bgcolor', context,
          CupertinoColors.systemBackground.resolveFrom(context))!,
      borderRadius: control.getBorderRadius('popup_border_radius') ??
          BorderRadius.circular(10),
      initialDisplayDuration:
          control.getDuration('popup_initial_display_duration', Duration.zero)!,
      mapEvents: MapController.maybeOf(context)?.mapEventStream,
    );
  }
}

/// Attribution popup that preserves permanent logos and map-dismissal behavior.
class CupertinoMapAttribution extends StatefulWidget {
  const CupertinoMapAttribution({
    super.key,
    required this.attributions,
    required this.logos,
    required this.backgroundColor,
    this.permanentHeight = 24,
    this.alignment = Alignment.bottomRight,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.initialDisplayDuration = Duration.zero,
    this.mapEvents,
  });

  final List<Widget> attributions, logos;
  final Color backgroundColor;
  final double permanentHeight;
  final Alignment alignment;
  final BorderRadius borderRadius;
  final Duration initialDisplayDuration;
  final Stream<dynamic>? mapEvents;

  @override
  State<CupertinoMapAttribution> createState() =>
      _CupertinoMapAttributionState();
}

class _CupertinoMapAttributionState extends State<CupertinoMapAttribution> {
  late bool _expanded = widget.initialDisplayDuration > Duration.zero;
  StreamSubscription<dynamic>? _mapEvents;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _listen();
    if (_expanded) _timer = Timer(widget.initialDisplayDuration, _close);
  }

  void _listen() {
    _mapEvents = widget.mapEvents?.listen((_) => _close());
  }

  void _close() {
    if (mounted && _expanded) setState(() => _expanded = false);
  }

  @override
  void didUpdateWidget(CupertinoMapAttribution oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mapEvents != oldWidget.mapEvents) {
      unawaited(_mapEvents?.cancel());
      _listen();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_mapEvents?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Align(
          alignment: widget.alignment,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: widget.alignment.x < 0
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                if (_expanded)
                  DecoratedBox(
                    decoration: BoxDecoration(
                        color: widget.backgroundColor,
                        borderRadius: widget.borderRadius),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.attributions,
                      ),
                    ),
                  ),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  ...widget.logos.expand((logo) =>
                      [logo, SizedBox(width: widget.permanentHeight / 1.5)]),
                  Semantics(
                    button: true,
                    label: _expanded ? 'Close attributions' : 'Attributions',
                    child: CupertinoButton(
                      padding: const EdgeInsets.all(4),
                      onPressed: () {
                        _timer?.cancel();
                        setState(() => _expanded = !_expanded);
                      },
                      child: Icon(
                          _expanded
                              ? CupertinoIcons.xmark_circle
                              : CupertinoIcons.info,
                          size: widget.permanentHeight),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
}
