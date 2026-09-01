import 'package:flutter/widgets.dart';

import '../models/page_design.dart';
import 'cupertino_empty_page.dart';
import 'material_empty_page.dart';

class PlatformEmptyPage extends StatelessWidget {
  final PageDesign design;
  final Widget child;

  const PlatformEmptyPage(
      {super.key, required this.design, required this.child});

  @override
  Widget build(BuildContext context) => switch (design) {
        PageDesign.material => MaterialEmptyPage(child: child),
        PageDesign.cupertino => CupertinoEmptyPage(child: child),
      };
}
