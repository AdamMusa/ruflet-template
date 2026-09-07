import 'package:flutter/material.dart';

class MaterialEmptyPage extends StatelessWidget {
  final Widget child;

  const MaterialEmptyPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(body: child);
}
