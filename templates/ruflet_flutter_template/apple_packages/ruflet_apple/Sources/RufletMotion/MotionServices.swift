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
        start(node: node, context: context)
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
      start(node: node, context: context)
    #endif
  }

  #if canImport(CoreMotion) && os(iOS)
    private func start(node: ControlNode, context: RufletServiceContext) {
      guard !running else { return }
      running = true

      let manager = Self.manager
      // Flet's sensors take a sampling interval in milliseconds.
      let interval = (node.double("sampling_rate") ?? 200) / 1000
      let id = node.id
      let queue = OperationQueue.main

      switch sensor {
      case .accelerometer:
        manager.accelerometerUpdateInterval = interval
        manager.startAccelerometerUpdates(to: queue) { data, _ in
          guard let data else { return }
          context.emitEvent(id, "change", Self.vector(data.acceleration))
        }
      case .userAccelerometer:
        manager.deviceMotionUpdateInterval = interval
        manager.startDeviceMotionUpdates(to: queue) { data, _ in
          guard let data else { return }
          context.emitEvent(id, "change", Self.vector(data.userAcceleration))
        }
      case .gyroscope:
        manager.gyroUpdateInterval = interval
        manager.startGyroUpdates(to: queue) { data, _ in
          guard let data else { return }
          context.emitEvent(
            id, "change",
            .map([
              "x": .double(data.rotationRate.x),
              "y": .double(data.rotationRate.y),
              "z": .double(data.rotationRate.z)
            ]))
        }
      case .magnetometer:
        manager.magnetometerUpdateInterval = interval
        manager.startMagnetometerUpdates(to: queue) { data, _ in
          guard let data else { return }
          context.emitEvent(
            id, "change",
            .map([
              "x": .double(data.magneticField.x),
              "y": .double(data.magneticField.y),
              "z": .double(data.magneticField.z)
            ]))
        }
      case .barometer:
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        let altimeter = CMAltimeter()
        self.altimeter = altimeter
        altimeter.startRelativeAltitudeUpdates(to: queue) { data, _ in
          guard let data else { return }
          context.emitEvent(
            id, "change",
            .map([
              // kPa on the wire, matching Flet's barometer payload.
              "pressure": .double(data.pressure.doubleValue),
              "relative_altitude": .double(data.relativeAltitude.doubleValue)
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

    private static func vector(_ acceleration: CMAcceleration) -> RufletValue {
      .map([
        "x": .double(acceleration.x),
        "y": .double(acceleration.y),
        "z": .double(acceleration.z)
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
public final class ShakeDetectorService: RufletService {
  public static let wireType = "ShakeDetector"

  private var running = false
  private var lastShake = Date.distantPast

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
      guard !running, CMMotionManager().isAccelerometerAvailable else { return }
      running = true

      // Flet's shake detector takes a g-force threshold and a minimum gap
      // between reported shakes.
      let threshold = node.double("shake_threshold_gravity") ?? 2.7
      let gap = (node.double("min_time_between_shakes") ?? 500) / 1000
      let id = node.id

      let manager = CMMotionManager()
      manager.accelerometerUpdateInterval = 0.05
      manager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
        guard let self, let data else { return }
        let force = sqrt(
          pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2)
            + pow(data.acceleration.z, 2))
        guard force > threshold, Date().timeIntervalSince(self.lastShake) > gap else { return }
        self.lastShake = Date()
        context.emitEvent(id, "shake", .null)
      }
    #endif
  }
}

