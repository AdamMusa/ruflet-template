import Foundation
import RufletEngine
import RufletProtocol

#if canImport(CoreMotion)
  import CoreMotion
#endif

/// The CoreMotion sensors: `Accelerometer`, `UserAccelerometer`, `Gyroscope`,
/// `Magnetometer` and `Barometer`.
///
/// All five behave identically from Ruby's side — they configure a sampling
/// interval and stream `reading` events — so one implementation serves them all,
/// parameterised by which motion feed to read.
@MainActor
public final class MotionSensorService: RufletStreamingService {
  public enum Sensor: String {
    case accelerometer
    case userAccelerometer
    case gyroscope
    case magnetometer
    case barometer
  }

  public static let wireType = "Accelerometer"

  private let sensor: Sensor
  private var running = false
  private var configuration: Configuration?

  private struct Configuration: Equatable {
    let enabled: Bool
    let intervalMilliseconds: Double
    let reportsReading: Bool
    let reportsError: Bool
    let cancelOnError: Bool
  }

  #if canImport(CoreMotion) && os(iOS)
    private static let manager = CMMotionManager()
    private var altimeter: Any?
  #endif

  public init(sensor: Sensor) {
    self.sensor = sensor
  }

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    // Flet's BaseSensorService exposes no invoke methods; configuration and
    // subscription lifetime are entirely driven by control updates.
    completion(
      .failure(RufletServiceError.unsupportedMethod(type: sensor.rawValue, method: call.name)))
  }

  /// Sensors stream without being asked: Ruby configures the control and waits
  /// for `on_change`, so sampling begins as soon as the control appears.
  public func activate(node: ControlNode, context: RufletServiceContext) {
    #if canImport(CoreMotion) && os(iOS)
      configure(node: node, context: context)
    #else
      let next = resolvedConfiguration(node: node)
      guard next != configuration else { return }
      configuration = next
      if next.enabled, next.reportsError {
        context.emitEvent(
          node.id, "error",
          FletMotionSensorSemantics.errorEvent(
            "\(sensor.rawValue) is not available on this platform"))
      }
    #endif
  }

  private func resolvedConfiguration(node: ControlNode) -> Configuration {
    Configuration(
      enabled: node.bool("enabled") ?? true,
      intervalMilliseconds: FletMotionSensorSemantics.intervalMilliseconds(
        node.props["interval"]),
      reportsReading: node.handlesEvent("reading"),
      reportsError: node.handlesEvent("error"),
      cancelOnError: node.bool("cancel_on_error") ?? true
    )
  }

  #if canImport(CoreMotion) && os(iOS)
    private func configure(node: ControlNode, context: RufletServiceContext) {
      let next = resolvedConfiguration(node: node)
      guard next != configuration else { return }
      stop()
      configuration = next
      guard next.enabled, next.reportsReading || next.reportsError else {
        return
      }
      start(node: node, context: context, configuration: next)
    }

    private func start(
      node: ControlNode,
      context: RufletServiceContext,
      configuration: Configuration
    ) {
      running = true

      let manager = Self.manager
      // Flet's sensors take a sampling interval in milliseconds.
      let interval = configuration.intervalMilliseconds / 1000
      let id = node.id
      let queue = OperationQueue.main

      let report: (RufletValue) -> Void = { value in
        if configuration.reportsReading { context.emitEvent(id, "reading", value) }
      }
      let reportError: (Error?) -> Void = { [weak self] error in
        guard let self else { return }
        if configuration.reportsError {
          context.emitEvent(
            id, "error",
            FletMotionSensorSemantics.errorEvent(
              error?.localizedDescription ?? "Unknown sensor error"))
        }
        if configuration.cancelOnError { self.stop() }
      }

      switch sensor {
      case .accelerometer:
        guard manager.isAccelerometerAvailable else {
          reportError(FletMotionSensorError.unavailable("Accelerometer"))
          return
        }
        manager.accelerometerUpdateInterval = interval
        manager.startAccelerometerUpdates(to: queue) { data, error in
          if let error { return reportError(error) }
          guard let data else { return }
          report(FletMotionSensorSemantics.accelerationReading(
            x: data.acceleration.x, y: data.acceleration.y, z: data.acceleration.z,
            motionTimestamp: data.timestamp, userAcceleration: false))
        }
      case .userAccelerometer:
        guard manager.isDeviceMotionAvailable else {
          reportError(FletMotionSensorError.unavailable("UserAccelerometer"))
          return
        }
        manager.deviceMotionUpdateInterval = interval
        manager.startDeviceMotionUpdates(to: queue) { data, error in
          if let error { return reportError(error) }
          guard let data else { return }
          report(FletMotionSensorSemantics.accelerationReading(
            x: data.userAcceleration.x, y: data.userAcceleration.y, z: data.userAcceleration.z,
            motionTimestamp: data.timestamp, userAcceleration: true))
        }
      case .gyroscope:
        guard manager.isGyroAvailable else {
          reportError(FletMotionSensorError.unavailable("Gyroscope"))
          return
        }
        manager.gyroUpdateInterval = interval
        manager.startGyroUpdates(to: queue) { data, error in
          if let error { return reportError(error) }
          guard let data else { return }
          report(FletMotionSensorSemantics.vectorReading(
            x: data.rotationRate.x, y: data.rotationRate.y, z: data.rotationRate.z,
            motionTimestamp: data.timestamp))
        }
      case .magnetometer:
        guard manager.isMagnetometerAvailable else {
          reportError(FletMotionSensorError.unavailable("Magnetometer"))
          return
        }
        manager.magnetometerUpdateInterval = interval
        manager.startMagnetometerUpdates(to: queue) { data, error in
          if let error { return reportError(error) }
          guard let data else { return }
          report(FletMotionSensorSemantics.vectorReading(
            x: data.magneticField.x, y: data.magneticField.y, z: data.magneticField.z,
            motionTimestamp: data.timestamp))
        }
      case .barometer:
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
          reportError(FletMotionSensorError.unavailable("Barometer"))
          return
        }
        let altimeter = CMAltimeter()
        self.altimeter = altimeter
        altimeter.startRelativeAltitudeUpdates(to: queue) { data, error in
          if let error { return reportError(error) }
          guard let data else { return }
          report(FletMotionSensorSemantics.barometerReading(
            pressureKilopascals: data.pressure.doubleValue,
            motionTimestamp: data.timestamp))
        }
      }
    }

    private func stop() {
      guard running else { return }
      running = false
      let manager = Self.manager
      switch sensor {
      case .accelerometer: manager.stopAccelerometerUpdates()
      case .userAccelerometer: manager.stopDeviceMotionUpdates()
      case .gyroscope: manager.stopGyroUpdates()
      case .magnetometer: manager.stopMagnetometerUpdates()
      case .barometer: (altimeter as? CMAltimeter)?.stopRelativeAltitudeUpdates()
      }
    }

  #endif

  deinit {
    #if canImport(CoreMotion) && os(iOS)
      if running {
        let manager = Self.manager
        switch sensor {
        case .accelerometer: manager.stopAccelerometerUpdates()
        case .userAccelerometer: manager.stopDeviceMotionUpdates()
        case .gyroscope: manager.stopGyroUpdates()
        case .magnetometer: manager.stopMagnetometerUpdates()
        case .barometer: (altimeter as? CMAltimeter)?.stopRelativeAltitudeUpdates()
        }
      }
    #endif
  }
}

private enum FletMotionSensorError: LocalizedError {
  case unavailable(String)

  var errorDescription: String? {
    switch self {
    case .unavailable(let name): return "\(name) is not available on this device"
    }
  }
}

/// Pure conversions from Core Motion into the exact values emitted by the
/// pinned sensors_plus/Flet adapters.
public enum FletMotionSensorSemantics {
  public static let normalIntervalMilliseconds = 200.0
  public static let standardGravity = 9.81

  public static func intervalMilliseconds(_ value: RufletValue?) -> Double {
    let parsed: Double?
    switch value {
    case .int(let milliseconds): parsed = Double(milliseconds)
    case .double(let milliseconds):
      parsed = milliseconds.isFinite ? Double(Int(milliseconds)) : nil
    case .extended(type: 3, let microseconds):
      parsed = Double(microseconds).map { $0 / 1_000 }
    case .map(let fields):
      func integer(_ key: String) -> Double { Double(fields[key]?.intValue ?? 0) }
      parsed =
        24 * 60 * 60 * 1_000 * integer("days")
        + 60 * 60 * 1_000 * integer("hours")
        + 60 * 1_000 * integer("minutes")
        + 1_000 * integer("seconds")
        + integer("milliseconds")
        + integer("microseconds") / 1_000
    default: parsed = nil
    }
    guard let parsed, parsed >= 0 else { return normalIntervalMilliseconds }
    return parsed
  }

  public static func accelerationReading(
    x: Double, y: Double, z: Double, motionTimestamp: TimeInterval,
    userAcceleration: Bool,
    bootEpoch: TimeInterval = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
  ) -> RufletValue {
    let timestamp = timestampValue(
      motionTimestamp: motionTimestamp, bootEpoch: bootEpoch,
      integerMicroseconds: userAcceleration)
    return .map([
      "x": .double(-x * standardGravity),
      "y": .double(-y * standardGravity),
      "z": .double(-z * standardGravity),
      "timestamp": timestamp,
    ])
  }

  public static func vectorReading(
    x: Double, y: Double, z: Double, motionTimestamp: TimeInterval,
    bootEpoch: TimeInterval = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
  ) -> RufletValue {
    .map([
      "x": .double(x), "y": .double(y), "z": .double(z),
      "timestamp": timestampValue(
        motionTimestamp: motionTimestamp, bootEpoch: bootEpoch, integerMicroseconds: false),
    ])
  }

  public static func barometerReading(
    pressureKilopascals: Double, motionTimestamp: TimeInterval,
    bootEpoch: TimeInterval = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime
  ) -> RufletValue {
    .map([
      "pressure": .double(pressureKilopascals * 10),
      "timestamp": timestampValue(
        motionTimestamp: motionTimestamp, bootEpoch: bootEpoch, integerMicroseconds: false),
    ])
  }

  public static func errorEvent(_ message: String) -> RufletValue {
    .map(["message": .string(message)])
  }

  private static func timestampValue(
    motionTimestamp: TimeInterval, bootEpoch: TimeInterval, integerMicroseconds: Bool
  ) -> RufletValue {
    let totalMicroseconds = Int64((bootEpoch + motionTimestamp) * 1_000_000)
    if integerMicroseconds { return .int(totalMicroseconds) }
    let seconds = totalMicroseconds / 1_000_000
    let microseconds = totalMicroseconds % 1_000_000
    let date = Date(timeIntervalSince1970: Double(seconds))
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return .extended(
      type: 1,
      string: String(format: "%@.%06lld+00:00", formatter.string(from: date), microseconds))
  }
}

/// `ShakeDetector` — a shake gesture built on the accelerometer.
@MainActor
public final class ShakeDetectorService: RufletStreamingService {
  public static let wireType = "ShakeDetector"

  private var running = false
  private var detectorState = FletShakeDetectorSemantics.State(
    timestampMilliseconds: FletShakeDetectorSemantics.nowMilliseconds(), count: 0)
  #if canImport(CoreMotion) && os(iOS)
    private var manager: CMMotionManager?
  #endif
  // Flet initializes these fields to the same defaults before its first
  // `update()`. Consequently the listener starts only when configuration
  // changes; preserving that lifecycle is important for source parity.
  private var configuration = FletShakeDetectorSemantics.Configuration.defaults

  public init() {}

  public func invoke(
    _ call: RufletMethodCall,
    node: ControlNode?,
    context: RufletServiceContext,
    completion: @escaping RufletMethodCompletion
  ) {
    completion(
      .failure(RufletServiceError.unsupportedMethod(type: "ShakeDetector", method: call.name)))
  }

  public func activate(node: ControlNode, context: RufletServiceContext) {
    #if canImport(CoreMotion) && os(iOS)
      let next = FletShakeDetectorSemantics.Configuration(
        minimumCount: node.int("minimum_shake_count") ?? 1,
        slopMilliseconds: node.int("shake_slop_time_ms") ?? 500,
        resetMilliseconds: node.int("shake_count_reset_time_ms") ?? 3_000,
        threshold: node.double("shake_threshold_gravity") ?? 2.7
      )
      guard next != configuration else { return }
      manager?.stopAccelerometerUpdates()
      running = false
      configuration = next

      let manager = CMMotionManager()
      guard manager.isAccelerometerAvailable else { return }
      self.manager = manager
      running = true

      let id = node.id

      // sensors_plus uses SensorInterval.normalInterval (200 ms).
      manager.accelerometerUpdateInterval = 0.2
      manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
        guard let self, let data else { return }
        if FletShakeDetectorSemantics.consume(
          x: data.acceleration.x, y: data.acceleration.y, z: data.acceleration.z,
          nowMilliseconds: FletShakeDetectorSemantics.nowMilliseconds(),
          configuration: next, state: &self.detectorState),
          context.store.node(id)?.handlesEvent("shake") == true
        {
          context.emitEvent(id, "shake", .null)
        }
      }
    #endif
  }

  deinit {
    #if canImport(CoreMotion) && os(iOS)
      manager?.stopAccelerometerUpdates()
    #endif
  }
}

public enum FletShakeDetectorSemantics {
  public static let sensorsPlusGravity = 9.81
  public static let detectorGravity = 9.80665
  public static let samplingIntervalSeconds = 0.2

  public struct Configuration: Equatable {
    public let minimumCount: Int
    public let slopMilliseconds: Int
    public let resetMilliseconds: Int
    public let threshold: Double

    public init(
      minimumCount: Int, slopMilliseconds: Int, resetMilliseconds: Int, threshold: Double
    ) {
      self.minimumCount = minimumCount
      self.slopMilliseconds = slopMilliseconds
      self.resetMilliseconds = resetMilliseconds
      self.threshold = threshold
    }

    public static let defaults = Configuration(
      minimumCount: 1, slopMilliseconds: 500, resetMilliseconds: 3_000, threshold: 2.7)
  }

  public struct State: Equatable {
    public var timestampMilliseconds: Int64
    public var count: Int

    public init(timestampMilliseconds: Int64, count: Int) {
      self.timestampMilliseconds = timestampMilliseconds
      self.count = count
    }
  }

  public static func nowMilliseconds(_ date: Date = Date()) -> Int64 {
    Int64(date.timeIntervalSince1970 * 1_000)
  }

  /// Applies the pinned Flet shake algorithm to a raw Core Motion acceleration
  /// sample. sensors_plus first flips axes and converts g to m/s²; signs cancel
  /// in the vector magnitude, but its 9.81/9.80665 scale remains observable.
  @discardableResult
  public static func consume(
    x: Double, y: Double, z: Double,
    nowMilliseconds: Int64,
    configuration: Configuration,
    state: inout State
  ) -> Bool {
    let scale = sensorsPlusGravity / detectorGravity
    let force = sqrt(x * x + y * y + z * z) * scale
    guard force > configuration.threshold else { return false }

    if state.timestampMilliseconds + Int64(configuration.slopMilliseconds) > nowMilliseconds {
      return false
    }
    if state.timestampMilliseconds + Int64(configuration.resetMilliseconds) < nowMilliseconds {
      state.count = 0
    }

    state.timestampMilliseconds = nowMilliseconds
    state.count += 1
    return state.count >= configuration.minimumCount
  }
}
