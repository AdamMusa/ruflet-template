import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet/src/core/control_core.dart';
import 'package:ruflet/src/core/control_spec.dart';
import 'package:ruflet/src/core/toggle_label.dart';
import 'package:ruflet/src/widgets/list_tile_clicks.dart';

import '../support/control_harness.dart';

const _box = SizedBox(key: ValueKey('toggle'), width: 40, height: 20);

Widget _app(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: child));

void main() {
  group('ToggleLabel', () {
    testWidgets('without a label it is the native toggle', (tester) async {
      await tester
          .pumpWidget(_app(const ToggleLabel(label: null, child: _box)));
      expect(find.byType(MergeSemantics), findsNothing);
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('places the label on either side with shared geometry',
        (tester) async {
      for (final position in LabelPosition.values) {
        await tester.pumpWidget(_app(ToggleLabel(
            label: const Text('On', key: ValueKey('label')),
            position: position,
            spacing: 6,
            onToggle: () {},
            child: _box)));
        final toggle = tester.getRect(find.byKey(const ValueKey('toggle')));
        final label = tester.getRect(find.byKey(const ValueKey('label')));
        if (position == LabelPosition.right) {
          expect(label.left - toggle.right, 6);
        } else {
          expect(toggle.left - label.right, 6);
        }
        expect(tester.getSize(find.byType(Row)).width,
            toggle.width + label.width + 6,
            reason: 'mainAxisSize.min by default');
      }
    });

    testWidgets('mainAxisSize max fills the row', (tester) async {
      await tester.pumpWidget(_app(const SizedBox(
          width: 300,
          child: ToggleLabel(
              label: Text('On'),
              mainAxisSize: MainAxisSize.max,
              child: _box))));
      expect(tester.getSize(find.byType(Row)).width, 300);
    });

    testWidgets('the label toggles and shows a click cursor while enabled',
        (tester) async {
      var toggles = 0;
      await tester.pumpWidget(_app(ToggleLabel(
          label: const Text('On'), onToggle: () => toggles++, child: _box)));
      await tester.tap(find.text('On'));
      expect(toggles, 1);
      expect(
          find.ancestor(
              of: find.text('On'),
              matching: find.byWidgetPredicate((w) =>
                  w is MouseRegion && w.cursor == SystemMouseCursors.click)),
          findsOneWidget);
    });

    testWidgets('a disabled label neither toggles nor shows a click cursor',
        (tester) async {
      await tester
          .pumpWidget(_app(const ToggleLabel(label: Text('On'), child: _box)));
      await tester.tap(find.text('On'));
      expect(
          find.ancestor(
              of: find.text('On'),
              matching: find.byWidgetPredicate((w) =>
                  w is MouseRegion && w.cursor == SystemMouseCursors.click)),
          findsNothing);
    });

    testWidgets('merges the label and the toggle into one semantics node',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(ToggleLabel(
          label: const Text('Wi-Fi'),
          onToggle: () {},
          child: Semantics(toggled: true, enabled: true, child: _box))));
      final node = tester.getSemantics(find.byType(Row));
      expect(node.label, 'Wi-Fi');
      expect(node.getSemanticsData().flagsCollection.toStrings(),
          containsAll(['hasToggledState', 'isToggled']));
      semantics.dispose();
    });
  });

  group('TileToggleCore', () {
    for (final disabled in [false, true]) {
      testWidgets('a tile tap toggles only an enabled control ($disabled)',
          (tester) async {
        final backend = HarnessBackend(HarnessDesign.android,
            extensions: [_TileExtension()]);
        final control = Control.fromMap(
            {'_c': 'CoreTile', '_i': 700, 'disabled': disabled}, backend);
        final clicks = ListTileClickNotifier();
        await tester.pumpWidget(harnessApp(
            backend,
            HarnessDesign.android,
            ListTileClicks(
                notifier: clicks, child: ControlWidget(control: control))));
        clicks.onClick();
        expect(_TileCore.last!.taps, disabled ? 0 : 1);

        await tester.pumpWidget(
            harnessApp(backend, HarnessDesign.android, const SizedBox()));
        clicks.onClick();
        expect(_TileCore.last!.taps, disabled ? 0 : 1,
            reason: 'unsubscribed on dispose');
        clicks.dispose();
      });
    }
  });
}

class _TileCore extends ControlCore<Object> with TileToggleCore<Object> {
  _TileCore(super.control) {
    last = this;
  }

  static _TileCore? last;
  int taps = 0;

  @override
  ControlSpec get spec => const ControlSpec(wireType: 'CoreTile', props: []);

  @override
  Object parse(PropReader r) => const Object();

  @override
  void onTileClick() => taps++;
}

class _TileExtension extends RufletExtension {
  @override
  Widget? createWidget(Key? key, Control control) => control.type != 'CoreTile'
      ? null
      : CoreHost<_TileCore>(
          control: control,
          create: _TileCore.new,
          builder: (context, core) => const SizedBox(width: 10, height: 10));
}
