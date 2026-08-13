import CoreGraphics
import Foundation
import RufletProtocol

public struct RufletEventPoint: Sendable, Equatable {
  public let x: Double
  public let y: Double

  public init(x: Double, y: Double) { self.x = x; self.y = y }
  public init(_ point: CGPoint) { self.init(x: point.x, y: point.y) }

  public var value: RufletValue { ["x": .double(x), "y": .double(y)] }
}

public struct RufletScaleStartDetails: Sendable, Equatable {
  public let focalPoint: RufletEventPoint
  public let localFocalPoint: RufletEventPoint
  public let pointerCount: Int
  public let timestamp: TimeInterval?

  public var value: RufletValue {
    eventValue([
      "gfp": focalPoint.value, "lfp": localFocalPoint.value,
      "pc": .int(Int64(pointerCount)), "ts": optionalDouble(timestamp),
    ])
  }
}

public struct RufletScaleUpdateDetails: Sendable, Equatable {
  public let focalPoint: RufletEventPoint
  public let focalPointDelta: RufletEventPoint
  public let localFocalPoint: RufletEventPoint
  public let pointerCount: Int
  public let horizontalScale: Double
  public let verticalScale: Double
  public let scale: Double
  public let rotation: Double
  public let timestamp: TimeInterval?

  public var value: RufletValue {
    eventValue([
      "gfp": focalPoint.value, "fpd": focalPointDelta.value,
      "lfp": localFocalPoint.value, "pc": .int(Int64(pointerCount)),
      "hs": .double(horizontalScale), "vs": .double(verticalScale),
      "s": .double(scale), "rot": .double(rotation), "ts": optionalDouble(timestamp),
    ])
  }
}

public struct RufletScaleEndDetails: Sendable, Equatable {
  public let pointerCount: Int
  public let velocity: RufletEventPoint

  public var value: RufletValue {
    eventValue(["pc": .int(Int64(pointerCount)), "v": velocity.value])
  }
}

public struct RufletPositionedGestureDetails: Sendable, Equatable {
  public let localPosition: RufletEventPoint
  public let globalPosition: RufletEventPoint
  public let deviceKind: String?

  public var value: RufletValue {
    eventValue([
      "k": optionalString(deviceKind), "l": localPosition.value, "g": globalPosition.value,
    ])
  }
}

public struct RufletDragStartDetails: Sendable, Equatable {
  public let localPosition: RufletEventPoint
  public let globalPosition: RufletEventPoint
  public let deviceKind: String?
  public let timestamp: TimeInterval?

  public var value: RufletValue {
    eventValue([
      "k": optionalString(deviceKind), "l": localPosition.value,
      "g": globalPosition.value, "ts": optionalDouble(timestamp),
    ])
  }
}

public struct RufletDragUpdateDetails: Sendable, Equatable {
  public let localPosition: RufletEventPoint
  public let globalPosition: RufletEventPoint
  public let previousLocalPosition: RufletEventPoint?
  public let previousGlobalPosition: RufletEventPoint?
  public let primaryDelta: Double?
  public let timestamp: TimeInterval?

  public var value: RufletValue {
    eventValue([
      "l": localPosition.value,
      "g": globalPosition.value,
      "ld": pointDelta(localPosition, previousLocalPosition),
      "gd": pointDelta(globalPosition, previousGlobalPosition),
      "pd": optionalDouble(primaryDelta),
      "ts": optionalDouble(timestamp),
    ])
  }
}

public struct RufletDragEndDetails: Sendable, Equatable {
  public let localPosition: RufletEventPoint
  public let globalPosition: RufletEventPoint
  public let velocity: RufletEventPoint
  public let primaryVelocity: Double?

  public var value: RufletValue {
    eventValue([
      "l": localPosition.value, "g": globalPosition.value, "v": velocity.value,
      "pv": optionalDouble(primaryVelocity),
    ])
  }
}

public struct RufletTapMoveDetails: Sendable, Equatable {
  public let localPosition: RufletEventPoint
  public let globalPosition: RufletEventPoint
  public let delta: RufletEventPoint
  public let deviceKind: String

  public var value: RufletValue {
    eventValue([
      "k": .string(deviceKind), "l": localPosition.value,
      "g": globalPosition.value, "d": delta.value,
    ])
  }
}

public struct RufletPointerEventDetails: Sendable, Equatable {
  public let deviceKind: String
  public let localPosition: RufletEventPoint
  public let globalPosition: RufletEventPoint
  public let previousLocalPosition: RufletEventPoint?
  public let timestamp: TimeInterval
  public let device: Int
  public let pressure: Double
  public let pressureMinimum: Double
  public let pressureMaximum: Double
  public let distance: Double
  public let distanceMaximum: Double
  public let size: Double
  public let radiusMajor: Double
  public let radiusMinor: Double
  public let radiusMinimum: Double
  public let radiusMaximum: Double
  public let orientation: Double
  public let tilt: Double

  public var value: RufletValue {
    eventValue([
      "k": .string(deviceKind), "l": localPosition.value, "g": globalPosition.value,
      "ts": .double(timestamp), "dev": .int(Int64(device)), "ps": .double(pressure),
      "pMin": .double(pressureMinimum), "pMax": .double(pressureMaximum),
      "dist": .double(distance), "distMax": .double(distanceMaximum), "size": .double(size),
      "rMj": .double(radiusMajor), "rMn": .double(radiusMinor),
      "rMin": .double(radiusMinimum), "rMax": .double(radiusMaximum),
      "or": .double(orientation), "tilt": .double(tilt),
      "ld": pointDelta(localPosition, previousLocalPosition),
    ])
  }
}

public struct RufletForcePressDetails: Sendable, Equatable {
  public let localPosition: RufletEventPoint
  public let globalPosition: RufletEventPoint
  public let pressure: Double

  public var value: RufletValue {
    eventValue([
      "l": localPosition.value, "g": globalPosition.value, "p": .double(pressure),
    ])
  }
}

public struct RufletPointerScrollDetails: Sendable, Equatable {
  public let localPosition: RufletEventPoint
  public let globalPosition: RufletEventPoint
  public let scrollDelta: RufletEventPoint

  public var value: RufletValue {
    eventValue([
      "l": localPosition.value, "g": globalPosition.value, "sd": scrollDelta.value,
    ])
  }
}

private func eventValue(_ fields: [String: RufletValue]) -> RufletValue { .map(fields) }
private func optionalDouble(_ value: Double?) -> RufletValue {
  value.map(RufletValue.double) ?? .null
}
private func optionalString(_ value: String?) -> RufletValue {
  value.map(RufletValue.string) ?? .null
}
private func pointDelta(
  _ current: RufletEventPoint, _ previous: RufletEventPoint?
) -> RufletValue {
  guard let previous else { return ["x": .null, "y": .null] }
  return RufletEventPoint(x: current.x - previous.x, y: current.y - previous.y).value
}
