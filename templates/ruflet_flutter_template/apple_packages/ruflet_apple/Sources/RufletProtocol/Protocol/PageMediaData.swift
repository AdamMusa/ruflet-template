public enum RufletOrientation: String, Equatable, Sendable {
  case portrait
  case landscape
}

public struct RufletPaddingData: Equatable, Sendable {
  public let top: Double
  public let right: Double
  public let bottom: Double
  public let left: Double

  public init(top: Double, right: Double, bottom: Double, left: Double) {
    self.top = top
    self.right = right
    self.bottom = bottom
    self.left = left
  }

  public static let zero = RufletPaddingData(top: 0, right: 0, bottom: 0, left: 0)

  public var value: RufletValue {
    ["top": .double(top), "right": .double(right), "bottom": .double(bottom), "left": .double(left)]
  }
}

public struct RufletPageMediaData: Equatable, Sendable {
  public let padding: RufletPaddingData
  public let viewPadding: RufletPaddingData
  public let viewInsets: RufletPaddingData
  public let devicePixelRatio: Double
  public let orientation: RufletOrientation
  public let alwaysUse24HourFormat: Bool

  public init(
    padding: RufletPaddingData,
    viewPadding: RufletPaddingData,
    viewInsets: RufletPaddingData,
    devicePixelRatio: Double,
    orientation: RufletOrientation,
    alwaysUse24HourFormat: Bool
  ) {
    self.padding = padding
    self.viewPadding = viewPadding
    self.viewInsets = viewInsets
    self.devicePixelRatio = devicePixelRatio
    self.orientation = orientation
    self.alwaysUse24HourFormat = alwaysUse24HourFormat
  }

  public var value: RufletValue {
    [
      "padding": padding.value,
      "view_padding": viewPadding.value,
      "view_insets": viewInsets.value,
      "device_pixel_ratio": .double(devicePixelRatio),
      "orientation": .string(orientation.rawValue),
      "always_use_24_hour_format": .bool(alwaysUse24HourFormat),
    ]
  }
}
