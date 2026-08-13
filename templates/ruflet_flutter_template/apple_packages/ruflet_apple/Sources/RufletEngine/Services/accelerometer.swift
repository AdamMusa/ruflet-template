import CoreMotion
import Foundation
import RufletProtocol

public struct RufletAccelerationReading: Sendable {
  public let x: Double
  public let y: Double
  public let z: Double
  public let timestamp: Date
}

@MainActor
public final class AccelerometerService: BaseSensorService<RufletAccelerationReading> {
  #if os(iOS)
  private let motionManager = CMMotionManager()
  private let queue = OperationQueue()
  #endif

  public override func startSensor(samplingPeriod: TimeInterval) {
    #if os(iOS)
    guard motionManager.isAccelerometerAvailable else {
      receive(error: RufletServiceError.unavailable("Accelerometer is unavailable"))
      return
    }
    motionManager.accelerometerUpdateInterval = samplingPeriod
    motionManager.startAccelerometerUpdates(to: queue) { [weak self] data, error in
      Task { @MainActor in
        guard let self else { return }
        if let error { self.receive(error: error); return }
        guard let data else { return }
        self.receive(RufletAccelerationReading(
          x: data.acceleration.x * 9.80665,
          y: data.acceleration.y * 9.80665,
          z: data.acceleration.z * 9.80665,
          timestamp: Date(timeIntervalSinceNow: data.timestamp - ProcessInfo.processInfo.systemUptime)))
      }
    }
    #else
    receive(error: RufletServiceError.unavailable("Accelerometer is unavailable on macOS"))
    #endif
  }

  public override func stopSensor() {
    #if os(iOS)
    motionManager.stopAccelerometerUpdates()
    #endif
  }

  public override func serializeEvent(_ event: RufletAccelerationReading) -> RufletValue {
    ["x": .double(event.x), "y": .double(event.y), "z": .double(event.z),
     "timestamp": serviceTimestamp(event.timestamp)]
  }
}
