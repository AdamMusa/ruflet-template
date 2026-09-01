import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import 'base_controls.dart';
import 'control_widget.dart';

Widget _destinationContent(Control destination,
    {required bool selected, required BuildContext context}) {
  final icon = selected
      ? destination.buildIconOrWidget("selected_icon") ??
          destination.buildIconOrWidget("icon")
      : destination.buildIconOrWidget("icon");
  final label = destination.buildTextOrWidget("label") ??
      Text(destination.getString("label", "")!);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[icon, const SizedBox(width: 8)],
      Flexible(child: label),
    ],
  );
}

class CupertinoNavigationBarDestinationControl extends StatelessWidget {
  final Control control;

  const CupertinoNavigationBarDestinationControl(
      {super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    return BaseControl(
      control: control,
      child: Semantics(
        label: control.getString("label", ""),
        button: true,
        enabled: !control.disabled,
        child: _destinationContent(control, selected: false, context: context),
      ),
    );
  }
}

class CupertinoNavigationDrawerControl extends StatelessWidget {
  final Control control;

  const CupertinoNavigationDrawerControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final selectedIndex = control.getInt("selected_index", 0)!;
    final destinations = control.children("controls");
    final drawer = ColoredBox(
      color: control.getColor("bgcolor", context) ??
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: SafeArea(
        child: ListView.builder(
          padding: control.getPadding("tile_padding", const EdgeInsets.all(12)),
          itemCount: destinations.length,
          itemBuilder: (context, index) {
            final destination = destinations[index];
            final selected = selectedIndex == index;
            if (destination.type != "NavigationDrawerDestination") {
              return ControlWidget(control: destination);
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: CupertinoButton(
                alignment: AlignmentDirectional.centerStart,
                color: selected
                    ? control.getColor("indicator_color", context) ??
                        CupertinoColors.systemGrey5.resolveFrom(context)
                    : null,
                onPressed: control.disabled || destination.disabled
                    ? null
                    : () {
                        control.updateProperties({"selected_index": index},
                            notify: true);
                        control.triggerEvent("change", index);
                      },
                child: _destinationContent(destination,
                    selected: selected, context: context),
              ),
            );
          },
        ),
      ),
    );
    return BaseControl(control: control, child: drawer);
  }
}

class CupertinoNavigationRailControl extends StatelessWidget {
  final Control control;

  const CupertinoNavigationRailControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final selectedIndex = control.getInt("selected_index", 0)!;
    final destinations = control.children("destinations");
    if (destinations.isEmpty) {
      return const ErrorControl(
          "NavigationRail must have at least one destination");
    }
    final rail = ColoredBox(
      color: control.getColor("bgcolor", context) ??
          CupertinoColors.secondarySystemBackground.resolveFrom(context),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            if (control.buildWidget("leading") case final leading?) leading,
            for (final (index, destination) in destinations.indexed)
              CupertinoButton(
                color: selectedIndex == index
                    ? control.getColor("indicator_color", context) ??
                        CupertinoColors.systemGrey5.resolveFrom(context)
                    : null,
                onPressed: control.disabled || destination.disabled
                    ? null
                    : () {
                        control.updateProperties({"selected_index": index},
                            notify: true);
                        control.triggerEvent("change", index);
                      },
                child: _destinationContent(destination,
                    selected: selectedIndex == index, context: context),
              ),
            const Spacer(),
            if (control.buildWidget("trailing") case final trailing?) trailing,
          ],
        ),
      ),
    );
    return LayoutControl(control: control, child: rail);
  }
}

class CupertinoMenuBarControl extends StatelessWidget {
  final Control control;

  const CupertinoMenuBarControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final controls = control.buildWidgets("controls");
    if (controls.isEmpty) {
      return const ErrorControl(
          "MenuBar must have at minimum one visible child control");
    }
    final menu = DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        border: Border(
          bottom: BorderSide(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: controls),
      ),
    );
    return LayoutControl(control: control, child: menu);
  }
}

class CupertinoMenuItemButtonControl extends StatelessWidget {
  final Control control;

  const CupertinoMenuItemButtonControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final leading = control.buildWidget("leading");
    final trailing = control.buildWidget("trailing_icon");
    final content = control.buildTextOrWidget("content");
    final button = CupertinoButton(
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onPressed: control.disabled || !control.getBool("on_click", false)!
          ? null
          : () => control.triggerEvent("click"),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 8)],
          if (content != null) Flexible(child: content),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
    return LayoutControl(control: control, child: button);
  }
}

Future<void> _showCupertinoMenu(
    BuildContext context, Control control, List<Control> entries) async {
  control.triggerEvent("open");
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => CupertinoPopupSurface(
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: ListView(
            shrinkWrap: true,
            children: entries
                .map((entry) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final value = entry.getString("value") ??
                            entry.getString("text") ??
                            entry.id.toString();
                        entry.triggerEvent("click");
                        control.triggerEvent("select", value);
                        Navigator.pop(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: ControlWidget(control: entry),
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    ),
  );
  control.triggerEvent("close");
}

class CupertinoSubmenuButtonControl extends StatelessWidget {
  final Control control;

  const CupertinoSubmenuButtonControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final content = control.buildTextOrWidget("content") ??
        const ErrorControl("SubmenuButton.content must be provided");
    final button = CupertinoButton(
      onPressed: control.disabled
          ? null
          : () => _showCupertinoMenu(
              context, control, control.children("controls")),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (control.buildWidget("leading") case final leading?) ...[
          leading,
          const SizedBox(width: 8)
        ],
        Flexible(child: content),
        const SizedBox(width: 8),
        control.buildWidget("trailing") ??
            const Icon(CupertinoIcons.chevron_right, size: 16),
      ]),
    );
    return LayoutControl(control: control, child: button);
  }
}

class CupertinoPopupMenuButtonControl extends StatelessWidget {
  final Control control;

  const CupertinoPopupMenuButtonControl({super.key, required this.control});

  @override
  Widget build(BuildContext context) {
    final content = control.buildTextOrWidget("content") ??
        control.buildIconOrWidget("icon") ??
        const Icon(CupertinoIcons.ellipsis);
    final button = CupertinoButton(
      padding: control.getPadding("padding", const EdgeInsets.all(8)),
      onPressed: control.disabled
          ? null
          : () =>
              _showCupertinoMenu(context, control, control.children("items")),
      child: content,
    );
    return LayoutControl(control: control, child: button);
  }
}
