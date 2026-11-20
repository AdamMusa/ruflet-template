import 'dart:async';

import 'package:ruflet_map/src/cupertino_attribution.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, IconButton, Tooltip;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'attribution preserves permanent logos, source actions and map dismissal',
      (tester) async {
    final events = StreamController<void>.broadcast();
    var clicked = 0;
    await tester.pumpWidget(CupertinoApp(
        home: CupertinoMapAttribution(
      attributions: [
        CupertinoButton(
            onPressed: () => clicked++, child: const Text('© Source'))
      ],
      logos: const [Text('Permanent logo')],
      backgroundColor: CupertinoColors.white,
      mapEvents: events.stream,
    )));
    expect(find.text('Permanent logo'), findsOneWidget);
    expect(find.text('© Source'), findsNothing);
    await tester.tap(find.byIcon(CupertinoIcons.info));
    await tester.pump();
    await tester.tap(find.text('© Source'));
    expect(clicked, 1);
    expect(find.byType(Material), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(Tooltip), findsNothing);
    events.add(null);
    await tester.pump();
    expect(find.text('© Source'), findsNothing);
    expect(find.text('Permanent logo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await events.close();
    expect(tester.takeException(), isNull);
  });

  testWidgets('initial attribution display duration closes the popup',
      (tester) async {
    await tester.pumpWidget(const CupertinoApp(
        home: CupertinoMapAttribution(
      attributions: [Text('© Source')],
      logos: [],
      backgroundColor: CupertinoColors.white,
      initialDisplayDuration: Duration(seconds: 1),
    )));
    expect(find.text('© Source'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('© Source'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a new map event stream dismisses the popup only once the user opened it',
      (tester) async {
    final first = StreamController<void>.broadcast();
    final second = StreamController<void>.broadcast();
    final events = ValueNotifier<Stream<void>>(first.stream);
    await tester.pumpWidget(CupertinoApp(
        home: ValueListenableBuilder<Stream<void>>(
      valueListenable: events,
      builder: (context, stream, _) => CupertinoMapAttribution(
        attributions: const [Text('© Source')],
        logos: const [],
        backgroundColor: CupertinoColors.white,
        initialDisplayDuration: const Duration(seconds: 1),
        mapEvents: stream,
      ),
    )));

    // During the initial display a rebuild with another stream does not
    // start listening, so its events leave the popup open.
    events.value = second.stream;
    await tester.pump();
    second.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.text('© Source'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('© Source'), findsNothing);

    // Once the user opened it, the popup follows the new stream only.
    await tester.tap(find.byIcon(CupertinoIcons.info));
    await tester.pump();
    events.value = first.stream;
    await tester.pump();
    second.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.text('© Source'), findsOneWidget);
    first.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.text('© Source'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    events.dispose();
    await first.close();
    await second.close();
    expect(tester.takeException(), isNull);
  });
}
