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
    let duration = animationDurationSeconds(value)
    guard let duration else { return nil }
    return RufletCurve.animation(value["curve"]?.stringValue, duration: duration)
  }

  /// Duration used by both SwiftUI interpolation and Flet's `animation_end`
  /// protocol callback. Keeping one parser prevents the visual animation and
  /// completion event from drifting apart.
  public static func animationDurationSeconds(_ value: RufletValue?) -> Double? {
    guard let milliseconds = value?.doubleValue ?? value?["duration"]?.doubleValue else {
      return nil
    }
    return max(milliseconds, 0) / 1000
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
  public static func continuousAlignment(_ value: RufletValue?) -> RufletAlignment? {
    guard let value else { return nil }

    if let name = value.stringValue {
      switch name.lowercased().replacingOccurrences(of: "_", with: "") {
      case "topleft", "topstart": return .topLeft
      case "topcenter", "top": return .topCenter
      case "topright", "topend": return .topRight
      case "centerleft", "centerstart": return .centerLeft
      case "center": return .center
      case "centerright", "centerend": return .centerRight
      case "bottomleft", "bottomstart": return .bottomLeft
      case "bottomcenter", "bottom": return .bottomCenter
      case "bottomright", "bottomend": return .bottomRight
      default: return nil
      }
    }

    guard let map = value.mapValue,
      let x = map["x"]?.doubleValue,
      let y = map["y"]?.doubleValue
    else { return nil }
    return RufletAlignment(x: x, y: y)
  }

  /// Compatibility for controls whose internal layout still uses SwiftUI's
  /// discrete guides. Container uses `continuousAlignment` and therefore does
  /// not pass through this lossy adapter.
  public static func alignment(_ value: RufletValue?) -> Alignment? {
    guard let alignment = continuousAlignment(value) else { return nil }
    return Alignment(
      horizontal: HorizontalAlignment(unit: alignment.x),
      vertical: VerticalAlignment(unit: alignment.y))
  }

  // MARK: - Geometry

  /// Flet applies `offset` with Flutter's `FractionalTranslation`: `(1, 0)`
  /// moves a control by its own width, not by one logical pixel.
  public static func offset(_ value: RufletValue?) -> CGSize? {
    guard let map = value?.mapValue else { return nil }
    return CGSize(width: map["x"]?.doubleValue ?? 0, height: map["y"]?.doubleValue ?? 0)
  }

  /// Full Flet `Rotate` wire shape. Keeping the presentation details together
  /// prevents the shared wrapper from silently dropping a non-centre pivot.
  public struct RotationPresentation: Equatable {
    public let radians: Double
    public let alignment: RufletAlignment
    public let origin: CGSize
    public let transformHitTests: Bool
    public let filterQuality: String?

    /// SwiftUI describes the pivot as a unit point. Flet adds `origin` (in
    /// logical pixels) to its alignment point, so the unit point may legally
    /// sit outside 0...1 just as Flutter's transform origin may sit outside.
    public func anchor(in size: CGSize) -> UnitPoint {
      let baseX = (alignment.x + 1) / 2
      let baseY = (alignment.y + 1) / 2
      return UnitPoint(
        x: baseX + (size.width == 0 ? 0 : origin.width / size.width),
        y: baseY + (size.height == 0 ? 0 : origin.height / size.height))
    }
  }

  /// `rotate` is either radians or the complete serialized `Rotate` object.
  public static func rotationPresentation(_ value: RufletValue?) -> RotationPresentation? {
    guard let value else { return nil }
    if let radians = value.doubleValue {
      return RotationPresentation(
        radians: radians, alignment: .center, origin: .zero,
        transformHitTests: true, filterQuality: nil)
    }
    guard let map = value.mapValue else { return nil }
    return RotationPresentation(
      radians: map["angle"]?.doubleValue ?? 0,
      alignment: continuousAlignment(map["alignment"]) ?? .center,
      origin: point(map["origin"]),
      transformHitTests: map["transform_hit_tests"]?.boolValue ?? true,
      filterQuality: filterQuality(map["filter_quality"]?.stringValue))
  }

  /// Backwards-compatible scalar adapter for callers which only need angle.
  public static func rotation(_ value: RufletValue?) -> Angle? {
    rotationPresentation(value).map { .radians($0.radians) }
  }

  /// Full Flet `Scale` wire shape, including its pivot and hit-test policy.
  public struct ScalePresentation: Equatable {
    public let factors: CGSize
    public let alignment: RufletAlignment
    public let origin: CGSize
    public let transformHitTests: Bool
    public let filterQuality: String?

    public func anchor(in size: CGSize) -> UnitPoint {
      let baseX = (alignment.x + 1) / 2
      let baseY = (alignment.y + 1) / 2
      return UnitPoint(
        x: baseX + (size.width == 0 ? 0 : origin.width / size.width),
        y: baseY + (size.height == 0 ? 0 : origin.height / size.height))
    }
  }

  /// `scale` is either a factor or the complete serialized `Scale` object.
  public static func scalePresentation(_ value: RufletValue?) -> ScalePresentation? {
    guard let value else { return nil }
    if let factor = value.doubleValue {
      return ScalePresentation(
        factors: CGSize(width: factor, height: factor), alignment: .center,
        origin: .zero, transformHitTests: true, filterQuality: nil)
    }
    guard let map = value.mapValue else { return nil }
    let factors: CGSize
    if let uniform = map["scale"]?.doubleValue {
      factors = CGSize(width: uniform, height: uniform)
    } else {
      factors = CGSize(
        width: map["scale_x"]?.doubleValue ?? 1,
        height: map["scale_y"]?.doubleValue ?? 1)
    }
    return ScalePresentation(
      factors: factors,
      alignment: continuousAlignment(map["alignment"]) ?? .center,
      origin: point(map["origin"]),
      transformHitTests: map["transform_hit_tests"]?.boolValue ?? true,
      filterQuality: filterQuality(map["filter_quality"]?.stringValue))
  }

  /// Backwards-compatible factor adapter.
  public static func scale(_ value: RufletValue?) -> CGSize? {
    scalePresentation(value)?.factors
  }

  private static func point(_ value: RufletValue?) -> CGSize {
    guard let map = value?.mapValue else { return .zero }
    return CGSize(
      width: map["x"]?.doubleValue ?? 0,
      height: map["y"]?.doubleValue ?? 0)
  }

  private static func filterQuality(_ value: String?) -> String? {
    guard let value = value?.lowercased(), ["none", "low", "medium", "high"].contains(value)
    else { return nil }
    return value
  }

  /// Flutter's `BlendMode` case names against SwiftUI's. Flutter's Skia set is
  /// larger than Core Graphics', so a mode with no counterpart composites
  /// normally rather than picking a different one.
  public static func blendMode(_ value: String?) -> BlendMode {
    switch value?.lowercased() {
    case "multiply": return .multiply
    case "screen": return .screen
    case "overlay": return .overlay
    case "darken": return .darken
    case "lighten": return .lighten
    case "colordodge": return .colorDodge
    case "colorburn": return .colorBurn
    case "hardlight": return .hardLight
    case "softlight": return .softLight
    case "difference": return .difference
    case "exclusion": return .exclusion
    case "hue": return .hue
    case "saturation": return .saturation
    case "color": return .color
    case "luminosity": return .luminosity
    case "plus": return .plusLighter
    case "srcin": return .sourceAtop
    case "dstout": return .destinationOut
    case "dstover": return .destinationOver
    default: return .normal
    }
  }

  /// Flutter's `BoxConstraints`, which Flet serialises as the four bounds.
  public struct SizeConstraints: Equatable {
    public var minWidth: CGFloat?
    public var maxWidth: CGFloat?
    public var minHeight: CGFloat?
    public var maxHeight: CGFloat?
  }

  /// `parseBoxConstraints` defaults the minimums to zero and the maximums to
  /// infinity. Neither is a bound SwiftUI can be given, so an absent or
  /// unbounded edge stays nil and the frame is left to size itself.
  public static func sizeConstraints(_ value: RufletValue?) -> SizeConstraints? {
    guard let map = value?.mapValue else { return nil }
    func bound(_ key: String) -> CGFloat? {
      guard let raw = map[key]?.doubleValue, raw.isFinite, raw > 0 else { return nil }
      return CGFloat(raw)
    }
    let constraints = SizeConstraints(
      minWidth: bound("min_width"), maxWidth: bound("max_width"),
      minHeight: bound("min_height"), maxHeight: bound("max_height"))
    return constraints == SizeConstraints() ? nil : constraints
  }

  /// Flet's `BorderRadius`: a number, or per-corner values.
  public static func cornerRadius(_ value: RufletValue?) -> CGFloat? {
    cornerRadii(value)?.maximum
  }

  /// Preserve Flutter's four independent `BorderRadius` corners. A missing
  /// corner remains square instead of inheriting the largest supplied radius.
  public static func cornerRadii(_ value: RufletValue?) -> RufletCornerRadii? {
    guard let value else { return nil }
    if let uniform = value.doubleValue {
      return RufletCornerRadii(uniform: CGFloat(uniform))
    }
    guard let map = value.mapValue else { return nil }
    let topLeft = map["top_left"]?.doubleValue ?? map["top_start"]?.doubleValue ?? 0
    let topRight = map["top_right"]?.doubleValue ?? map["top_end"]?.doubleValue ?? 0
    let bottomLeft = map["bottom_left"]?.doubleValue ?? map["bottom_start"]?.doubleValue ?? 0
    let bottomRight = map["bottom_right"]?.doubleValue ?? map["bottom_end"]?.doubleValue ?? 0
    guard topLeft != 0 || topRight != 0 || bottomLeft != 0 || bottomRight != 0 else {
      return nil
    }
    return RufletCornerRadii(
      topLeft: CGFloat(topLeft), topRight: CGFloat(topRight),
      bottomLeft: CGFloat(bottomLeft), bottomRight: CGFloat(bottomRight))
  }

  /// Compatibility for controls which truly expose one stroke.
  public static func border(_ value: RufletValue?) -> (color: Color, width: CGFloat)? {
    guard let border = borderSides(value) else { return nil }
    for side in [border.top, border.left, border.right, border.bottom] {
      if let side { return (side.color, side.width) }
    }
    return nil
  }

  /// Flet permits a different color and width on every border edge. Preserve
  /// all four sides rather than selecting the first non-empty edge.
  public static func borderSides(_ value: RufletValue?) -> RufletBorder? {
    guard let map = value?.mapValue else { return nil }

    func side(_ value: RufletValue?) -> RufletBorderSide? {
      guard let map = value?.mapValue,
            let width = map["width"]?.doubleValue,
            width > 0 else { return nil }
      return RufletBorderSide(
        color: MaterialPalette.color(map["color"]?.stringValue, default: .black),
        width: CGFloat(width))
    }

    if map["width"] != nil {
      let uniform = side(value)
      return uniform.map { RufletBorder(top: $0, right: $0, bottom: $0, left: $0) }
    }
    let result = RufletBorder(
      top: side(map["top"]), right: side(map["right"]),
      bottom: side(map["bottom"]), left: side(map["left"]))
    return result.isEmpty ? nil : result
  }
}

public struct RufletBorderSide {
  public let color: Color
  public let width: CGFloat

  public init(color: Color, width: CGFloat) {
    self.color = color
    self.width = width
  }
}

public struct RufletBorder {
  public let top: RufletBorderSide?
  public let right: RufletBorderSide?
  public let bottom: RufletBorderSide?
  public let left: RufletBorderSide?

  public init(
    top: RufletBorderSide?, right: RufletBorderSide?,
    bottom: RufletBorderSide?, left: RufletBorderSide?
  ) {
    self.top = top
    self.right = right
    self.bottom = bottom
    self.left = left
  }

  public var isEmpty: Bool { top == nil && right == nil && bottom == nil && left == nil }
}

public struct RufletCornerRadii: Equatable, Sendable {
  public let topLeft: CGFloat
  public let topRight: CGFloat
  public let bottomLeft: CGFloat
  public let bottomRight: CGFloat

  public init(topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
    self.topLeft = max(0, topLeft)
    self.topRight = max(0, topRight)
    self.bottomLeft = max(0, bottomLeft)
    self.bottomRight = max(0, bottomRight)
  }

  public init(uniform: CGFloat) {
    self.init(topLeft: uniform, topRight: uniform, bottomLeft: uniform, bottomRight: uniform)
  }

  public var maximum: CGFloat { max(topLeft, topRight, bottomLeft, bottomRight) }
}

/// Platform-neutral equivalent of Flutter's `RRect.fromRectAndCorners`.
/// Adjacent radii are proportionally normalized when they exceed an edge.
public struct RufletRoundedRectangle: Shape {
  public let radii: RufletCornerRadii

  public init(radii: RufletCornerRadii) { self.radii = radii }

  public func path(in rect: CGRect) -> Path {
    let scale = min(
      1,
      ratio(rect.width, radii.topLeft + radii.topRight),
      ratio(rect.width, radii.bottomLeft + radii.bottomRight),
      ratio(rect.height, radii.topLeft + radii.bottomLeft),
      ratio(rect.height, radii.topRight + radii.bottomRight))
    let tl = radii.topLeft * scale
    let tr = radii.topRight * scale
    let bl = radii.bottomLeft * scale
    let br = radii.bottomRight * scale

    var path = Path()
    path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
    if tr > 0 {
      path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tr),
                        control: CGPoint(x: rect.maxX, y: rect.minY))
    }
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
    if br > 0 {
      path.addQuadCurve(to: CGPoint(x: rect.maxX - br, y: rect.maxY),
                        control: CGPoint(x: rect.maxX, y: rect.maxY))
    }
    path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
    if bl > 0 {
      path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bl),
                        control: CGPoint(x: rect.minX, y: rect.maxY))
    }
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
    if tl > 0 {
      path.addQuadCurve(to: CGPoint(x: rect.minX + tl, y: rect.minY),
                        control: CGPoint(x: rect.minX, y: rect.minY))
    }
    path.closeSubpath()
    return path
  }

  private func ratio(_ extent: CGFloat, _ sum: CGFloat) -> CGFloat {
    sum > 0 ? extent / sum : 1
  }
}

/// Flutter's continuous `Alignment(x, y)` coordinate space. Values are not
/// clamped: Flutter permits alignments outside -1...1 as well.
public struct RufletAlignment: Equatable, Sendable {
  public let x: Double
  public let y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }

  public static let topLeft = RufletAlignment(x: -1, y: -1)
  public static let topCenter = RufletAlignment(x: 0, y: -1)
  public static let topRight = RufletAlignment(x: 1, y: -1)
  public static let centerLeft = RufletAlignment(x: -1, y: 0)
  public static let center = RufletAlignment(x: 0, y: 0)
  public static let centerRight = RufletAlignment(x: 1, y: 0)
  public static let bottomLeft = RufletAlignment(x: -1, y: 1)
  public static let bottomCenter = RufletAlignment(x: 0, y: 1)
  public static let bottomRight = RufletAlignment(x: 1, y: 1)
}

/// Pure geometry shared by the SwiftUI layouts and parity tests.
enum RufletGeometry {
  static func fractionalTranslation(fraction: CGSize, childSize: CGSize) -> CGSize {
    CGSize(
      width: fraction.width * childSize.width,
      height: fraction.height * childSize.height)
  }

  static func alignedOrigin(
    alignment: RufletAlignment,
    containerSize: CGSize,
    childSize: CGSize
  ) -> CGPoint {
    CGPoint(
      x: (containerSize.width - childSize.width) * CGFloat((alignment.x + 1) / 2),
      y: (containerSize.height - childSize.height) * CGFloat((alignment.y + 1) / 2))
  }

  static func unitPoint(alignment: RufletAlignment) -> CGPoint {
    CGPoint(
      x: CGFloat((alignment.x + 1) / 2),
      y: CGFloat((alignment.y + 1) / 2))
  }
}

extension HorizontalAlignment {
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
