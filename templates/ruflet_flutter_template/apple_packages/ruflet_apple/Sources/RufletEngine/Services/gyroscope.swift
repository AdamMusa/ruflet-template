import CoreMotion
import Foundation
import RufletProtocol

public struct RufletGyroscopeReading: Sendable {
  public let x: Double
  public let y: Double
  public let z: Double
  public let timestamp: Date

  public init(x: Double, y: Double, z: Double, timestamp: Date) {
    self.x = x
    self.y = y
    self.z = z
    self.timestamp = timestamp
  }
}

@MainActor
public final class GyroscopeService: BaseSensorService<RufletGyroscopeReading> {
  #if os(iOS)
  private let motionManager = CMMotionManager()
  private let queue = OperationQueue()
  #endif

  public override func startSensor(samplingPeriod: TimeInterval) {
    #if os(iOS)
    guard motionManager.isGyroAvailable else {
      receive(error: RufletServiceError.unavailable("Gyroscope is unavailable"))
      return
    }
    motionManager.gyroUpdateInterval = samplingPeriod
    motionManager.startGyroUpdates(to: queue) { [weak self] data, error in
      Task { @MainActor in
        guard let self else { return }
        if let error { self.receive(error: error); return }
        guard let data else { return }
        self.receive(RufletGyroscopeReading(
          x: data.rotationRate.x, y: data.rotationRate.y, z: data.rotationRate.z,
          timestamp: Date(timeIntervalSinceNow: data.timestamp - ProcessInfo.processInfo.systemUptime)))
      }
    }
    #else
    receive(error: RufletServiceError.unavailable("Gyroscope is unavailable on macOS"))
    #endif
  }

  public override func stopSensor() {
    #if os(iOS)
    motionManager.stopGyroUpdates()
    #endif
  }

  public override func serializeEvent(_ event: RufletGyroscopeReading) -> RufletValue {
    ["x": .double(event.x), "y": .double(event.y), "z": .double(event.z),
     "timestamp": serviceTimestamp(event.timestamp)]
  }
}
