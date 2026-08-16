import RufletProtocol
import SwiftUI

private struct RufletSelectionAreaReporterKey: EnvironmentKey {
  static let defaultValue: ((String, RufletTextSelection) -> Void)? = nil
}

extension EnvironmentValues {
  var rufletSelectionAreaReporter: ((String, RufletTextSelection) -> Void)? {
    get { self[RufletSelectionAreaReporterKey.self] }
    set { self[RufletSelectionAreaReporterKey.self] = newValue }
  }
}

@MainActor
public struct SelectionAreaControl: View {
  @ObservedObject public var control: RufletControl
  public init(control: RufletControl) { self.control = control }

  @ViewBuilder
  public var body: some View {
    if let content = control.buildWidget("content") {
      BaseControl(control: control) {
        content
          .textSelection(.enabled)
          .environment(\.rufletSelectionAreaReporter) { text, selection in
            rufletSelectionAreaChanged(control: control, text: text, selection: selection)
          }
      }
    } else {
      ErrorControl("SelectionArea.content must be provided and visible")
    }
  }
}

@MainActor
func rufletSelectionAreaChanged(
  control: RufletControl,
  text: String,
  selection: RufletTextSelection
) {
  let range = selection.range
  let utf16 = text as NSString
  let selected: RufletValue
  if range.length > 0, range.location >= 0, NSMaxRange(range) <= utf16.length {
    selected = .string(utf16.substring(with: range))
  } else {
    selected = .null
  }
  control.triggerEvent("change", data: selected)
}
