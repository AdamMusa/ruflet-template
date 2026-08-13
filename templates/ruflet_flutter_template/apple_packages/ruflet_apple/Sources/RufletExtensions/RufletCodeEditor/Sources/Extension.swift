import RufletEngine
import SwiftUI

@MainActor
public struct RufletCodeEditorExtension: RufletExtension {
  public init() {}

  public var renderedControlTypes: Set<String> { RufletCodeEditor.controlTypes }

  public func createView(for control: RufletControl) -> AnyView? {
    control.type == "CodeEditor" ? AnyView(CodeEditorControl(control: control)) : nil
  }
}
