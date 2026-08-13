import RufletProtocol

public struct RufletWindowState: Equatable, Sendable {
  public var maximized: Bool
  public var minimized: Bool
  public var fullScreen: Bool
  public var alwaysOnTop: Bool
  public var focused: Bool
  public var visible: Bool
  public var minimizable: Bool
  public var maximizable: Bool
  public var resizable: Bool
  public var preventClose: Bool
  public var skipTaskBar: Bool
  public var width: Double
  public var height: Double
  public var top: Double
  public var left: Double
  public var opacity: Double

  public var value: RufletValue {
    [
      "maximized": .bool(maximized),
      "minimized": .bool(minimized),
      "full_screen": .bool(fullScreen),
      "always_on_top": .bool(alwaysOnTop),
      "focused": .bool(focused),
      "visible": .bool(visible),
      "width": .double(width),
      "height": .double(height),
      "top": .double(top),
      "left": .double(left),
      "opacity": .double(opacity),
    ]
  }
}
