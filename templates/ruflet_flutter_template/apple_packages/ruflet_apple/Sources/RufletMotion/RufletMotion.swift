import RufletEngine

/// The CoreMotion services: the four sensors, the barometer and shake
/// detection.
///
/// A separate module because linking CoreMotion is what makes iOS ask for
/// `NSMotionUsageDescription`. An app that never reads a sensor should not be
/// asked for one, and should not carry the sampling code.
///
/// ```swift
/// RufletAppView(services: [RufletMotion.self])
/// ```
@MainActor
public enum RufletMotion: RufletServiceBundle {
  public static let bundleName = "RufletMotion"

  public static func register(in registry: ServiceRegistry) {
    registry.registerNamed("Accelerometer") { MotionSensorService(sensor: .accelerometer) }
    registry.registerNamed("UserAccelerometer") { MotionSensorService(sensor: .userAccelerometer) }
    registry.registerNamed("Gyroscope") { MotionSensorService(sensor: .gyroscope) }
    registry.registerNamed("Magnetometer") { MotionSensorService(sensor: .magnetometer) }
    registry.registerNamed("Barometer") { MotionSensorService(sensor: .barometer) }
    registry.registerNamed("ShakeDetector") { ShakeDetectorService() }

    registry.markStreaming(
      ["accelerometer", "useraccelerometer", "gyroscope", "magnetometer", "barometer",
       "shakedetector"])
  }
}
