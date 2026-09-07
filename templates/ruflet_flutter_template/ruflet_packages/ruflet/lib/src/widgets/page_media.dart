import 'package:flutter/widgets.dart';

import '../ruflet_backend.dart';
import '../models/control.dart';
import '../protocol/page_media_data.dart';
import '../utils/debouncer.dart';

class PageMedia extends StatefulWidget {
  final Control? view;
  const PageMedia({super.key, this.view});

  @override
  State<PageMedia> createState() => _PageMediaState();
}

class _PageMediaState extends State<PageMedia> {
  final _debouncer = Debouncer(milliseconds: 100);

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  _onPageSizeChanged(bool pageSizeUpdated, Size newSize) {
    var backend = RufletBackend.of(context);
    if (pageSizeUpdated) {
      _debouncer.run(() {
        backend.updatePageSize(newSize, view: widget.view);
      });
    } else {
      backend.updatePageSize(newSize, view: widget.view);
    }
  }

  _onPlatformBrightnessChanged(Brightness newBrightness) {
    RufletBackend.of(context).updateBrightness(newBrightness);
  }

  _onMediaChanged(PageMediaData newMedia) {
    RufletBackend.of(context).updateMedia(newMedia, view: widget.view);
  }

  @override
  Widget build(BuildContext context) {
    RufletBackend backend = RufletBackend.of(context);
    // Subscribe during build, before deferring notifications until after layout.
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final newMedia = PageMediaData(
      padding: PaddingData(MediaQuery.paddingOf(context)),
      viewPadding: PaddingData(MediaQuery.viewPaddingOf(context)),
      viewInsets: PaddingData(MediaQuery.viewInsetsOf(context)),
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      orientation: MediaQuery.orientationOf(context),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final pageSize = MediaQuery.sizeOf(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      var pageSizeUpdated = backend.pageSizeUpdated.isCompleted;

      if (platformBrightness != backend.platformBrightness ||
          !pageSizeUpdated) {
        _onPlatformBrightnessChanged(platformBrightness);
      }

      if (newMedia != backend.media || !pageSizeUpdated) {
        _onMediaChanged(newMedia);
      }

      if (pageSize != backend.pageSize) {
        _onPageSizeChanged(pageSizeUpdated, pageSize);
      }
    });

    return const SizedBox.shrink();
  }
}
