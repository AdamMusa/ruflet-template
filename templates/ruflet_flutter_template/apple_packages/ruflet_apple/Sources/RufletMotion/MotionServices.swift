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
/// interval and stream `change` events — so one implementation serves them all,
/// parameterised by which motion feed to read.
@MainActor
public final class MotionSensorService: RufletService {
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
    let reportsLegacyChange: Bool
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
    #if canImport(CoreMotion) && os(iOS)
      guard let node else {
        return completion(.failure(RufletServiceError.unknownTarget(call.controlID)))
      }
      switch call.name {
      case "start", "resume":
        // An explicit start reuses the configuration the control was set up
        // with; `configure` would decline to act on an unchanged one.
        let resolved = configuration ?? resolvedConfiguration(node: node)
        configuration = resolved
        start(node: node, context: context, configuration: resolved)
        completion(.success(.null))
      case "stop", "pause":
        stop()
        completion(.success(.null))
      default:
        completion(
          .failure(
            RufletServiceError.unsupportedMethod(type: sensor.rawValue, method: call.name)))
      }
    #else
      completion(
        .failure(
          RufletServiceError.unavailable("\(sensor.rawValue) is not available on this platform")))
    #endif
  }

  /// Sensors stream without being asked: Ruby configures the control and waits
  /// for `on_change`, so sampling begins as soon as the control appears.
  public func activate(node: ControlNode, context: RufletServiceContext) {
    #if canImport(CoreMotion) && os(iOS)
      configure(node: node, context: context)
    #endif
  }

  #if canImport(CoreMotion) && os(iOS)
    private func resolvedConfiguration(node: ControlNode) -> Configuration {
      Configuration(
        enabled: node.bool("enabled") ?? true,
        intervalMilliseconds: max(0, node.double("interval") ?? node.double("sampling_rate") ?? 200),
        reportsReading: node.handlesEvent("reading"),
        reportsLegacyChange: node.handlesEvent("change"),
        reportsError: node.handlesEvent("error"),
        cancelOnError: node.bool("cancel_on_error") ?? true
      )
    }

    private func configure(node: ControlNode, context: RufletServiceContext) {
      let next = resolvedConfiguration(node: node)
      guard next != configuration else { return }
      stop()
      configuration = next
      guard next.enabled, next.reportsReading || next.reportsLegacyChange || next.reportsError else {
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
        if configuration.reportsLegacyChange { context.emitEvent(id, "change", value) }
      }
      let reportError: (Error?) -> Void = { [weak self] error in
        guard let self else { return }
        if configuration.reportsError {
          context.emitEvent(id, "error", .map([
            "message": .string(error?.localizedDescription ?? "Unknown sensor error")
          ]))
        }
        if configuration.cancelOnError { self.stop() }
      }

      switch sensor {
      case .accelerometer:
        manager.accelerometerUpdateInterval = interval
        manager.startAccelerometerUpdates(to: queue) { data, error in
          if let error { return reportError(error) }
          guard let data else { return }
          report(Self.vector(data.acceleration, timestamp: data.timestamp))
        }
      case .userAccelerometer:
        manager.deviceMotionUpdateInterval = interval
        manager.startDeviceMotionUpdates(to: queue) { data, error in
          if let error { return reportError(error) }
          guard let data else { return }
          report(Self.vector(data.userAcceleration, timestamp: data.timestamp))
        }
      case .gyroscope:
        manager.gyroUpdateInterval = interval
        manager.startGyroUpdates(to: queue) { data, error in
          if let error { return reportError(error) }
          guard let data else { return }
          report(.map([
            "x": .double(data.rotationRate.x),
            "y": .double(data.rotationRate.y),
            "z": .double(data.rotationRate.z),
            "timestamp": .double(data.timestamp)
          ]))
        }
      case .magnetometer:
        manager.magnetometerUpdateInterval = interval
        manager.startMagnetometerUpdates(to: queue) { data, error in
          if let error { return reportError(error) }
          guard let data else { return }
          report(.map([
            "x": .double(data.magneticField.x),
            "y": .double(data.magneticField.y),
            "z": .double(data.magneticField.z),
            "timestamp": .double(data.timestamp)
          ]))
        }
      case .barometer:
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
          reportError(nil)
          return
        }
        let altimeter = CMAltimeter()
        self.altimeter = altimeter
        altimeter.startRelativeAltitudeUpdates(to: queue) { data, error in
          if let error { return reportError(error) }
          guard let data else { return }
          report(.map([
            // kPa on the wire, matching Flet's barometer payload.
            "pressure": .double(data.pressure.doubleValue),
            "timestamp": .double(ProcessInfo.processInfo.systemUptime)
          ]))
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

    private static func vector(_ acceleration: CMAcceleration, timestamp: TimeInterval) -> RufletValue {
      .map([
        "x": .double(acceleration.x),
        "y": .double(acceleration.y),
        "z": .double(acceleration.z),
        "timestamp": .double(timestamp)
      ])
    }
  #endif

  deinit {
    #if canImport(CoreMotion) && os(iOS)
      // `stop()` is main-actor isolated; the shared manager can be told
      // directly from any thread.
      if running {
        let manager = Self.manager
        manager.stopAccelerometerUpdates()
        manager.stopDeviceMotionUpdates()
        manager.stopGyroUpdates()
        manager.stopMagnetometerUpdates()
      }
    #endif
  }
}

/// `ShakeDetector` — a shake gesture built on the accelerometer.
@MainActor
public final class ShakeDetectorService: RufletStreamingService {
  public static let wireType = "ShakeDetector"

  private var running = false
  private var lastShake = Date.distantPast
  private var shakeCount = 0
  #if canImport(CoreMotion) && os(iOS)
    private var manager: CMMotionManager?
  #endif
  private var configuration: Configuration?

  private struct Configuration: Equatable {
    let minimumCount: Int
    let slopMilliseconds: Double
    let resetMilliseconds: Double
    let threshold: Double
  }

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
      let next = Configuration(
        minimumCount: max(1, node.int("minimum_shake_count") ?? 1),
        slopMilliseconds: max(0, node.double("shake_slop_time_ms") ?? node.double("min_time_between_shakes") ?? 500),
        resetMilliseconds: max(0, node.double("shake_count_reset_time_ms") ?? 3_000),
        threshold: node.double("shake_threshold_gravity") ?? 2.7
      )
      guard next != configuration else { return }
      manager?.stopAccelerometerUpdates()
      running = false
      shakeCount = 0
      configuration = next

      let manager = CMMotionManager()
      guard manager.isAccelerometerAvailable else { return }
      self.manager = manager
      running = true

      let id = node.id

      manager.accelerometerUpdateInterval = 0.05
      manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
        guard let self, let data else { return }
        let force = sqrt(
          pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2)
            + pow(data.acceleration.z, 2))
        let now = Date()
        guard force > next.threshold,
          now.timeIntervalSince(self.lastShake) * 1_000 > next.slopMilliseconds
        else { return }
        if now.timeIntervalSince(self.lastShake) * 1_000 > next.resetMilliseconds {
          self.shakeCount = 0
        }
        self.lastShake = now
        self.shakeCount += 1
        if self.shakeCount >= next.minimumCount {
          self.shakeCount = 0
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
