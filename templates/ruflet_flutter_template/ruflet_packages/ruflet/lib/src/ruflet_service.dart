import 'package:flutter/foundation.dart';

import 'models/control.dart';

abstract class RufletService {
  Control control;

  RufletService({required this.control});

  @mustCallSuper
  void init() {}

  void update() {}

  @mustCallSuper
  void dispose() {}
}
