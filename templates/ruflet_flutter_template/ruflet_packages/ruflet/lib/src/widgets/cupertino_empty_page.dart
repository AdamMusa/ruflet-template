import 'package:flutter/cupertino.dart';

class CupertinoEmptyPage extends StatelessWidget {
  final Widget child;

  const CupertinoEmptyPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(child: child);
}
