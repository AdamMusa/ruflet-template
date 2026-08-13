import RufletEngine
import SwiftUI

@MainActor
public struct RufletDataTable2Extension: RufletExtension {
  public init() {}

  public var renderedControlTypes: Set<String> { RufletDataTable2.controlTypes }

  public func createView(for control: RufletControl) -> AnyView? {
    control.type == "DataTable2" ? AnyView(DataTable2Control(control: control)) : nil
  }
}
