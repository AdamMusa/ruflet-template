import CoreMotion
import Foundation
import RufletProtocol

public struct RufletMagnetometerReading: Sendable {
  public let x: Double
  public let y: Double
  public let z: Double
  public let timestamp: Date
}

@MainActor
public final class MagnetometerService: BaseSensorService<RufletMagnetometerReading> {
  #if os(iOS)
  private let motionManager = CMMotionManager()
  private let queue = OperationQueue()
  #endif

  public override func startSensor(samplingPeriod: TimeInterval) {
    #if os(iOS)
    guard motionManager.isMagnetometerAvailable else {
      receive(error: RufletServiceError.unavailable("Magnetometer is unavailable"))
      return
    }
    motionManager.magnetometerUpdateInterval = samplingPeriod
    motionManager.startMagnetometerUpdates(to: queue) { [weak self] data, error in
      Task { @MainActor in
        guard let self else { return }
        if let error { self.receive(error: error); return }
        guard let data else { return }
        self.receive(RufletMagnetometerReading(
          x: data.magneticField.x, y: data.magneticField.y, z: data.magneticField.z,
          timestamp: Date(timeIntervalSinceNow: data.timestamp - ProcessInfo.processInfo.systemUptime)))
      }
    }
    #else
    receive(error: RufletServiceError.unavailable("Magnetometer is unavailable on macOS"))
    #endif
  }

  public override func stopSensor() {
    #if os(iOS)
    motionManager.stopMagnetometerUpdates()
    #endif
  }

  public override func serializeEvent(_ event: RufletMagnetometerReading) -> RufletValue {
    ["x": .double(event.x), "y": .double(event.y), "z": .double(event.z),
     "timestamp": serviceTimestamp(event.timestamp)]
  }
}
