import 'package:flutter/widgets.dart';

class ListTileClicks extends InheritedWidget {
  const ListTileClicks({
    super.key,
    required this.notifier,
    required super.child,
  });

  final ListTileClickNotifier notifier;

  static ListTileClicks? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ListTileClicks>();
  }

  @override
  bool updateShouldNotify(ListTileClicks oldWidget) => true;
}

class ListTileClickNotifier extends ChangeNotifier {
  void onClick() {
    notifyListeners();
  }
}
