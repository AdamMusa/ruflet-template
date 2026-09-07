import 'package:flutter/cupertino.dart';

import '../controls/cupertino_selection_area.dart';

class CupertinoStartupApp extends StatelessWidget {
  final String title;
  final bool isLoading;
  final String message;

  const CupertinoStartupApp(
      {super.key,
      required this.title,
      required this.isLoading,
      required this.message});

  @override
  Widget build(BuildContext context) => CupertinoApp(
        title: title,
        debugShowCheckedModeBanner: false,
        home: CupertinoLoadingPage(
            title: isLoading ? null : title,
            isLoading: isLoading,
            message: message),
      );
}

class CupertinoLoadingPage extends StatelessWidget {
  final bool isLoading;
  final String message;
  final String? title;

  const CupertinoLoadingPage(
      {super.key, required this.isLoading, required this.message, this.title});

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    Widget? content;
    if (isLoading) {
      content = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CupertinoActivityIndicator(radius: 15),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(message, style: theme.textTheme.tabLabelTextStyle),
        ],
      ]);
    } else if (message.isNotEmpty) {
      final errorColor = CupertinoColors.systemRed.resolveFrom(context);
      content = Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: errorColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(CupertinoIcons.exclamationmark_circle,
              color: errorColor, size: 30),
          const SizedBox(width: 8),
          Flexible(
              child: CupertinoSelectableRegion(
                  child: Text(message,
                      softWrap: true,
                      style: theme.textTheme.textStyle
                          .copyWith(color: errorColor)))),
        ]),
      );
    }
    return CupertinoPageScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      navigationBar:
          title == null ? null : CupertinoNavigationBar(middle: Text(title!)),
      child: SizedBox.expand(child: Center(child: content)),
    );
  }
}

class CupertinoErrorControl extends StatelessWidget {
  final String message;
  final String? description;

  const CupertinoErrorControl(this.message, {super.key, this.description});

  @override
  Widget build(BuildContext context) => CupertinoSelectableRegion(
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              color: CupertinoColors.systemRed.resolveFrom(context),
              borderRadius: BorderRadius.circular(3)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message,
                style: const TextStyle(
                    color: CupertinoColors.white, fontSize: 12)),
            if (description != null) ...[
              const SizedBox(height: 5),
              Text(description!,
                  style:
                      const TextStyle(color: Color(0xb3ffffff), fontSize: 11)),
            ],
          ]),
        ),
      );
}
