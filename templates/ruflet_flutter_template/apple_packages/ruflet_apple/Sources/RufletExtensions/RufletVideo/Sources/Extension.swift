import RufletEngine
import SwiftUI

@MainActor
public struct RufletVideoExtension: RufletExtension {
  public init() {}

  public var renderedControlTypes: Set<String> { RufletVideo.controlTypes }

  public func createView(for control: RufletControl) -> AnyView? {
    control.type == "Video" ? AnyView(VideoControl(control: control)) : nil
  }
}
