import CoreMotion
import Foundation
import RufletProtocol

@MainActor
public final class UserAccelerometerService: BaseSensorService<RufletAccelerationReading> {
  #if os(iOS)
  private let motionManager = CMMotionManager()
  private let queue = OperationQueue()
  #endif

  public override func startSensor(samplingPeriod: TimeInterval) {
    #if os(iOS)
    guard motionManager.isDeviceMotionAvailable else {
      receive(error: RufletServiceError.unavailable("User accelerometer is unavailable"))
      return
    }
    motionManager.deviceMotionUpdateInterval = samplingPeriod
    motionManager.startDeviceMotionUpdates(to: queue) { [weak self] data, error in
      Task { @MainActor in
        guard let self else { return }
        if let error { self.receive(error: error); return }
        guard let data else { return }
        self.receive(RufletAccelerationReading(
          x: data.userAcceleration.x * 9.80665,
          y: data.userAcceleration.y * 9.80665,
          z: data.userAcceleration.z * 9.80665,
          timestamp: Date(timeIntervalSinceNow: data.timestamp - ProcessInfo.processInfo.systemUptime)))
      }
    }
    #else
    receive(error: RufletServiceError.unavailable("User accelerometer is unavailable on macOS"))
    #endif
  }

  public override func stopSensor() {
    #if os(iOS)
    motionManager.stopDeviceMotionUpdates()
    #endif
  }

  public override func serializeEvent(_ event: RufletAccelerationReading) -> RufletValue {
    let micros = Int64((event.timestamp.timeIntervalSince1970 * 1_000_000).rounded())
    return ["x": .double(event.x), "y": .double(event.y), "z": .double(event.z),
            "timestamp": .int(micros)]
  }
}
