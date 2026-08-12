import RufletEngine
import RufletUI
import SwiftUI

/// Optional native renderer for Flet's `flet_code_editor` package.
///
/// Applications register this extension only when their Ruby control tree uses
/// `CodeEditor`; otherwise neither the editor implementation nor its native
/// text-system bridge is linked into the application binary.
@MainActor
public enum RufletCodeEditor: RufletExtension {
  public static let extensionName = "RufletCodeEditor"

  public static func register(in _: ServiceRegistry) {
    ControlRegistry.register(
      descriptor: ControlDescriptor(
        wireType: "CodeEditor",
        classification: .visible,
        implementation: "RufletCodeEditor.CodeEditorControlView",
        rendering: .nativeView,
        supportedEvents: ["blur", "change", "focus", "selection_change"],
        supportedMethods: ["focus", "fold_at", "fold_comment_at_line_zero", "fold_imports"])
    ) { node, _ in
      AnyView(CodeEditorControlView(node: node))
    }
  }
}
