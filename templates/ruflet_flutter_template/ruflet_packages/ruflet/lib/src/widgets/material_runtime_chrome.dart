import 'package:flutter/material.dart';

class MaterialStartupApp extends StatelessWidget {
  final String title;
  final bool isLoading;
  final String message;

  const MaterialStartupApp(
      {super.key,
      required this.title,
      required this.isLoading,
      required this.message});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: title,
        debugShowCheckedModeBanner: false,
        home: MaterialLoadingPage(
            title: isLoading ? null : title,
            isLoading: isLoading,
            message: message),
      );
}

class MaterialLoadingPage extends StatelessWidget {
  final bool isLoading;
  final String message;
  final String? title;

  const MaterialLoadingPage(
      {super.key, required this.isLoading, required this.message, this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget? content;
    if (isLoading) {
      content = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 3)),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(message, style: theme.textTheme.bodySmall),
        ],
      ]);
    } else if (message.isNotEmpty) {
      content = Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline,
              color: theme.colorScheme.onErrorContainer, size: 30),
          const SizedBox(width: 8),
          Flexible(
              child: SelectionArea(
                  child: Text(message,
                      softWrap: true,
                      style: theme.textTheme.bodySmall!.copyWith(
                          color: theme.colorScheme.onErrorContainer)))),
        ]),
      );
    }
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: title == null ? null : AppBar(title: Text(title!)),
      body: SizedBox.expand(child: Center(child: content)),
    );
  }
}

class MaterialErrorControl extends StatelessWidget {
  final String message;
  final String? description;

  const MaterialErrorControl(this.message, {super.key, this.description});

  @override
  Widget build(BuildContext context) => SelectionArea(
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              color: Colors.red, borderRadius: BorderRadius.circular(3)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            if (description != null) ...[
              const SizedBox(height: 5),
              Text(description!,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ]),
        ),
      );
}
