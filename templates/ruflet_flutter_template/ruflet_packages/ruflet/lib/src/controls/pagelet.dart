import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../models/control_type.dart';
import '../models/page_design.dart';
import '../utils/colors.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import '../widgets/ruflet_store_mixin.dart';
import '../widgets/platform_page_scaffold.dart';
import '../widgets/platform_control_renderer.dart';
import 'adaptive_app_bar.dart';
import 'base_controls.dart';
import 'control_widget.dart';

class PageletControl extends StatefulWidget {
  final Control control;

  PageletControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<PageletControl> createState() => _PageletControlState();
}

class _PageletControlState extends State<PageletControl> with RufletStoreMixin {
  final _scaffoldController = PlatformPageScaffoldController();

  @override
  void initState() {
    super.initState();
    widget.control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void dispose() {
    widget.control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("Pagelet.$name($args)");
    switch (name) {
      case "show_drawer":
        _scaffoldController.showDrawer();
        break;
      case "close_drawer":
        _scaffoldController.closeDrawer();
        break;
      case "show_end_drawer":
        _scaffoldController.showEndDrawer();
        break;
      case "close_end_drawer":
        _scaffoldController.closeEndDrawer();
        break;
      default:
        throw Exception("Unknown Pagelet method: $name");
    }
  }

  @override
  Widget build(BuildContext context) {
    return withPagePlatform(_buildForPlatform);
  }

  Widget _buildForPlatform(BuildContext context, TargetPlatform platform) {
    debugPrint("Pagelet build: ${widget.control.id}");

    var appBar = widget.control.child("appbar");
    var content = widget.control.buildWidget("content");
    var navigationBar = widget.control.buildWidget("navigation_bar");
    var bottomAppBar = widget.control.buildWidget("bottom_appbar");
    var bottomSheet = widget.control.buildWidget("bottom_sheet");
    var drawer = widget.control.child("drawer");
    var endDrawer = widget.control.child("end_drawer");
    var hasDrawer = drawer != null || endDrawer != null;
    var fab = widget.control.buildWidget("floating_action_button");

    if (content == null) {
      return const ErrorControl("Pagelet.content must be provided and visible");
    }

    var widgetsDesign = usesCupertinoControls(platform)
        ? PageDesign.cupertino
        : PageDesign.material;

    var bnb = navigationBar ?? bottomAppBar;

    void dismissDrawer(int id) {
      widget.control.backend.triggerControlEventById(id, "dismiss");
    }

    var bar = appBar != null
        ? appBar.canonicalType == "AppBar"
            ? AdaptiveAppBarControl(control: appBar)
            : null
        : null;

    Widget scaffold = PlatformPageScaffold(
        controller: _scaffoldController,
        design: widgetsDesign,
        backgroundColor: widget.control.getColor("bgcolor", context),
        appBar: bar,
        drawer: drawer != null ? ControlWidget(control: drawer) : null,
        onDrawerChanged: (opened) {
          if (drawer != null && !opened) {
            dismissDrawer(drawer.id);
          }
        },
        endDrawer: endDrawer != null ? ControlWidget(control: endDrawer) : null,
        onEndDrawerChanged: (opened) {
          if (endDrawer != null && !opened) {
            dismissDrawer(endDrawer.id);
          }
        },
        body: content,
        bottomNavigationBar: bnb,
        bottomSheet: bottomSheet,
        floatingActionButton: fab,
        floatingActionButtonLocation:
            widget.control.get("floating_action_button_location"));

    if (hasDrawer) {
      // Clip to page bounds so the drawer animation stays hidden outside the pagelet.
      scaffold = ClipRect(child: scaffold);
    }

    final scaffoldWithBoundsCheck = scaffold;

    scaffold = LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      debugPrint("Pagelet constraints.maxWidth: ${constraints.maxWidth}");
      debugPrint("Pagelet constraints.maxHeight: ${constraints.maxHeight}");

      if (constraints.maxHeight == double.infinity &&
          widget.control.getDouble("height") == null) {
        return const ErrorControl(
            "Error displaying Pagelet: height is unbounded.",
            description:
                "Either set a fixed \"height\" or nest Pagelet inside expanded control or control with a fixed height.");
      }

      return scaffoldWithBoundsCheck;
    });

    return LayoutControl(control: widget.control, child: scaffold);
  }
}
