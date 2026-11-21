import '../models/control.dart';

extension ControlPresentation on Control {
  /// Whether the page presents this control from its `_dialogs` layer
  /// (Ruby's page.show_dialog, page.open and page.dialog =) rather than
  /// laying it out. The view stacks that layer over the page body, so a
  /// control hosted there has no place in the layout and presents itself.
  /// Controls nested inside a presented control (a bottom sheet's content)
  /// are laid out by it and are not presented.
  bool get presentedByPage {
    final host = parent;
    return host != null &&
        identical(host.parent?.child("_dialogs", visibleOnly: false), host);
  }
}
