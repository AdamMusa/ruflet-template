import '../ruflet_backend.dart';
import '../ruflet_service.dart';
import '../models/control.dart';

class ServiceBinding {
  final Control control;
  final RufletBackend backend;
  RufletService? _service;

  ServiceBinding({required this.control, required this.backend}) {
    for (var extension in backend.extensions) {
      _service = extension.createService(control);
      if (_service != null) {
        break;
      }
    }
    if (_service == null) {
      throw Exception("Unknown service: ${control.type}");
    }
    _service?.init();
    // A service registers its invoke listeners in init(), if it has any on
    // this platform; methods it does not handle now fail fast.
    control.attach();
    control.addListener(_onControlUpdated);
  }

  void dispose() {
    control.removeListener(_onControlUpdated);
    control.detach();
    _service?.dispose();
  }

  void _onControlUpdated() {
    _service?.update();
  }
}
