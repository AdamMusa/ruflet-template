import CoreMotion
import Foundation
import RufletProtocol

public struct RufletBarometerReading: Sendable {
  public let pressure: Double
  public let timestamp: Date

  public init(pressure: Double, timestamp: Date) {
    self.pressure = pressure
    self.timestamp = timestamp
  }
}

@MainActor
public final class BarometerService: BaseSensorService<RufletBarometerReading> {
  #if os(iOS)
  private let altimeter = CMAltimeter()
  private let queue = OperationQueue()
  #endif

  public override func startSensor(samplingPeriod: TimeInterval) {
    #if os(iOS)
    guard CMAltimeter.isRelativeAltitudeAvailable() else {
      receive(error: RufletServiceError.unavailable("Barometer is unavailable"))
      return
    }
    altimeter.startRelativeAltitudeUpdates(to: queue) { [weak self] data, error in
      Task { @MainActor in
        guard let self else { return }
        if let error { self.receive(error: error); return }
        guard let data else { return }
        // Core Motion reports kilopascals; sensors_plus exposes hectopascals.
        self.receive(RufletBarometerReading(
          pressure: data.pressure.doubleValue * 10,
          timestamp: Date(timeIntervalSinceNow: data.timestamp - ProcessInfo.processInfo.systemUptime)))
      }
    }
    #else
    receive(error: RufletServiceError.unavailable("Barometer is unavailable on macOS"))
    #endif
  }

  public override func stopSensor() {
    #if os(iOS)
    altimeter.stopRelativeAltitudeUpdates()
    #endif
  }

  public override func serializeEvent(_ event: RufletBarometerReading) -> RufletValue {
    ["pressure": .double(event.pressure), "timestamp": serviceTimestamp(event.timestamp)]
  }
}
