import RufletEngine
import RufletProtocol
import SwiftUI

/// Reads the shared Flet property vocabulary off a node.
///
/// Almost every Ruflet control accepts the same layout, geometry and
/// interaction props (`expand`, `visible`, `opacity`, `margin`, `padding`,
/// `alignment`, `rotate`, `scale`, `offset`, `tooltip`, `disabled`, …). Flet
/// applies these in a shared wrapper rather than per widget; the same applies
/// here, so a new control only implements what makes it that control.
public enum ControlProps {

  // MARK: - Animation

  /// Ruflet accepts either milliseconds or an Animation map. SwiftUI owns the
  /// interpolation; the renderer only translates duration and curve.
  public static func animation(_ value: RufletValue?) -> Animation? {
    guard let value else { return nil }
    let duration = (value.doubleValue ?? value["duration"]?.doubleValue).map { $0 / 1000 }
    guard let duration else { return nil }
    let curve = value["curve"]?.stringValue?.lowercased() ?? "easeinout"
    switch curve.replacingOccurrences(of: "_", with: "") {
    case "linear": return .linear(duration: duration)
    case "easein": return .easeIn(duration: duration)
    case "easeout": return .easeOut(duration: duration)
    case "fastoutslowin", "easeinout": return .easeInOut(duration: duration)
    case "bounceout", "elasticout": return .spring(response: duration, dampingFraction: 0.62)
    default: return .easeInOut(duration: duration)
    }
  }

  // MARK: - Padding and margin

  /// Flet's `Padding`/`Margin`: either a number applied to all sides, or a map
  /// with any of `left`, `top`, `right`, `bottom`.
  public static func edgeInsets(_ value: RufletValue?) -> EdgeInsets? {
    guard let value else { return nil }
    if let uniform = value.doubleValue {
      return EdgeInsets(top: uniform, leading: uniform, bottom: uniform, trailing: uniform)
    }
    guard let map = value.mapValue else { return nil }
    return EdgeInsets(
      top: map["top"]?.doubleValue ?? 0,
      leading: map["left"]?.doubleValue ?? 0,
      bottom: map["bottom"]?.doubleValue ?? 0,
      trailing: map["right"]?.doubleValue ?? 0)
  }

  // MARK: - Alignment

  /// Flet's `MainAxisAlignment`, used by Row/Column `alignment`.
  public enum MainAxisAlignment: String {
    case start
    case end
    case center
    case spaceBetween
    case spaceAround
    case spaceEvenly

    public init(_ raw: String?) {
      switch raw?.lowercased().replacingOccurrences(of: "_", with: "") {
      case "end": self = .end
      case "center": self = .center
      case "spacebetween": self = .spaceBetween
      case "spacearound": self = .spaceAround
      case "spaceevenly": self = .spaceEvenly
      default: self = .start
      }
    }

    /// True when SwiftUI needs interleaved spacers rather than a stack
    /// alignment to express this.
    public var usesSpacers: Bool {
      self == .spaceBetween || self == .spaceAround || self == .spaceEvenly
    }
  }

  /// Flet's `CrossAxisAlignment`, used by `vertical_alignment` on a Row and
  /// `horizontal_alignment` on a Column.
  public enum CrossAxisAlignment: String {
    case start
    case end
    case center
    case stretch
    case baseline

    public init(_ raw: String?, default defaultValue: CrossAxisAlignment = .start) {
      switch raw?.lowercased() {
      case "end": self = .end
      case "center": self = .center
      case "stretch": self = .stretch
      case "baseline": self = .baseline
      case "start": self = .start
      default: self = defaultValue
      }
    }

    public var vertical: VerticalAlignment {
      switch self {
      case .start: return .top
      case .end: return .bottom
      case .center, .stretch: return .center
      case .baseline: return .firstTextBaseline
      }
    }

    public var horizontal: HorizontalAlignment {
      switch self {
      case .start: return .leading
      case .end: return .trailing
      case .center, .stretch, .baseline: return .center
      }
    }
  }

  /// Flet's two-dimensional `Alignment`, either a named constant or an
  /// `{x:, y:}` pair in the -1…1 coordinate space Flutter uses.
  public static func alignment(_ value: RufletValue?) -> Alignment? {
    guard let value else { return nil }

    if let name = value.stringValue {
      switch name.lowercased().replacingOccurrences(of: "_", with: "") {
      case "topleft", "topstart": return .topLeading
      case "topcenter", "top": return .top
      case "topright", "topend": return .topTrailing
      case "centerleft", "centerstart": return .leading
      case "center": return .center
      case "centerright", "centerend": return .trailing
      case "bottomleft", "bottomstart": return .bottomLeading
      case "bottomcenter", "bottom": return .bottom
      case "bottomright", "bottomend": return .bottomTrailing
      default: return nil
      }
    }

    guard let map = value.mapValue,
      let x = map["x"]?.doubleValue,
      let y = map["y"]?.doubleValue
    else { return nil }
    return Alignment(
      horizontal: HorizontalAlignment(unit: x),
      vertical: VerticalAlignment(unit: y))
  }

  // MARK: - Geometry

  public static func offset(_ value: RufletValue?) -> CGSize? {
    guard let map = value?.mapValue else { return nil }
    return CGSize(width: map["x"]?.doubleValue ?? 0, height: map["y"]?.doubleValue ?? 0)
  }

  /// `rotate` is either radians or `{angle:}`, matching Flet's `Rotate`.
  public static func rotation(_ value: RufletValue?) -> Angle? {
    guard let value else { return nil }
    if let radians = value.doubleValue { return .radians(radians) }
    if let angle = value["angle"]?.doubleValue { return .radians(angle) }
    return nil
  }

  /// `scale` is either a factor or `{scale:}`/`{scale_x:, scale_y:}`.
  public static func scale(_ value: RufletValue?) -> CGSize? {
    guard let value else { return nil }
    if let factor = value.doubleValue { return CGSize(width: factor, height: factor) }
    guard let map = value.mapValue else { return nil }
    if let uniform = map["scale"]?.doubleValue {
      return CGSize(width: uniform, height: uniform)
    }
    return CGSize(
      width: map["scale_x"]?.doubleValue ?? 1,
      height: map["scale_y"]?.doubleValue ?? 1)
  }

  /// Flet's `BorderRadius`: a number, or per-corner values.
  public static func cornerRadius(_ value: RufletValue?) -> CGFloat? {
    guard let value else { return nil }
    if let uniform = value.doubleValue { return CGFloat(uniform) }
    guard let map = value.mapValue else { return nil }
    let corners = [
      "top_left", "top_right", "bottom_left", "bottom_right"
    ].compactMap { map[$0]?.doubleValue }
    guard let first = corners.first else { return nil }
    // SwiftUI shapes take one radius; use the largest so a rounded corner is
    // never silently squared off.
    return CGFloat(corners.max() ?? first)
  }

  /// Flet's `Border`/`BorderSide`, reduced to the single stroke SwiftUI draws.
  public static func border(_ value: RufletValue?) -> (color: Color, width: CGFloat)? {
    guard let map = value?.mapValue else { return nil }
    let side = map["top"]?.mapValue ?? map["left"]?.mapValue ?? map
    guard let width = side["width"]?.doubleValue, width > 0 else { return nil }
    return (MaterialPalette.color(side["color"]?.stringValue, default: .gray), CGFloat(width))
  }
}

extension HorizontalAlignment {
  /// Maps Flutter's -1…1 alignment axis onto the three SwiftUI guides.
  fileprivate init(unit: Double) {
    switch unit {
    case ..<(-0.34): self = .leading
    case 0.34...: self = .trailing
    default: self = .center
    }
  }
}

extension VerticalAlignment {
  fileprivate init(unit: Double) {
    switch unit {
    case ..<(-0.34): self = .top
    case 0.34...: self = .bottom
    default: self = .center
    }
  }
}
