import SwiftUI

public enum RufletDashOffset: Equatable, Sendable {
  case absolute(Double)
  case percentage(Double)

  fileprivate func distance(for length: Double) -> Double {
    switch self {
    case .absolute(let value): return value
    case .percentage(let value): return length * min(max(value, 0), 1)
    }
  }
}

public final class CircularIntervalList<Value> {
  private let values: [Value]
  private var index = 0

  public init(_ values: [Value]) {
    precondition(!values.isEmpty, "CircularIntervalList cannot be empty")
    self.values = values
  }

  public var next: Value {
    if index >= values.count { index = 0 }
    defer { index += 1 }
    return values[index]
  }

  public var allValues: [Value] { values }
}

/// Returns a CoreGraphics-dashed copy of the source path.
public func dashPath(
  _ source: Path,
  dashArray: CircularIntervalList<Double>,
  dashOffset: RufletDashOffset = .absolute(0)
) -> Path {
  let bounds = source.boundingRect
  let approximateLength = max(Double(bounds.width + bounds.height) * 2, 1)
  let lengths = dashArray.allValues.map { CGFloat(max($0, 0)) }
  guard lengths.contains(where: { $0 > 0 }) else { return Path() }
  let phase = CGFloat(dashOffset.distance(for: approximateLength))
  let dashed = source.cgPath.copy(dashingWithPhase: phase, lengths: lengths)
  return Path(dashed)
}
