import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../ruflet_backend.dart';
import '../models/page_size_view_model.dart';

mixin RufletStoreMixin {
  Widget withPageSize(Widget Function(BuildContext, PageSizeViewModel) build) {
    return Selector<RufletBackend, PageSizeViewModel>(
      selector: (_, backend) => PageSizeViewModel(
          size: backend.pageSize, breakpoints: backend.sizeBreakpoints),
      builder: (context, view, _) => build(context, view),
    );
  }

  Widget withPagePlatform(Widget Function(BuildContext, TargetPlatform) build) {
    return Selector<RufletBackend, TargetPlatform>(
      selector: (_, backend) => backend.platform,
      builder: (context, platform, _) => build(context, platform),
    );
  }
}
