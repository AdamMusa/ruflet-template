import XCTest

import RufletEngine
@testable import RufletMotion
import RufletProtocol

final class MotionSensorParityTests: XCTestCase {
  func testFletNormalAndNegativeIntervals() {
    XCTAssertEqual(FletMotionSensorSemantics.intervalMilliseconds(nil), 200)
    XCTAssertEqual(FletMotionSensorSemantics.intervalMilliseconds(.int(16)), 16)
    XCTAssertEqual(FletMotionSensorSemantics.intervalMilliseconds(.double(16.9)), 16)
    XCTAssertEqual(
      FletMotionSensorSemantics.intervalMilliseconds(.extended(type: 3, string: "16667")),
      16.667, accuracy: 0.000_1)
    XCTAssertEqual(FletMotionSensorSemantics.intervalMilliseconds(.int(-1)), 200)
  }

  func testDurationMapIntervalUsesEveryFletDurationComponent() {
    XCTAssertEqual(
      FletMotionSensorSemantics.intervalMilliseconds(.map([
        "seconds": .int(1), "milliseconds": .int(250), "microseconds": .int(500),
      ])),
      1_250.5)
  }

  func testAccelerometerUsesSensorsPlusGravitySignAndDateTime() {
    XCTAssertEqual(
      FletMotionSensorSemantics.accelerationReading(
        x: 1, y: -2, z: 0.5, motionTimestamp: 0.25,
        userAcceleration: false, bootEpoch: 1_704_067_200),
      .map([
        "x": .double(-9.81), "y": .double(19.62), "z": .double(-4.905),
        "timestamp": .extended(type: 1, string: "2024-01-01T00:00:00.250000+00:00"),
      ]))
  }

  func testUserAccelerometerUsesIntegerEpochMicroseconds() {
    let value = FletMotionSensorSemantics.accelerationReading(
      x: 0, y: 0, z: 0, motionTimestamp: 0.25,
      userAcceleration: true, bootEpoch: 1_704_067_200)
    XCTAssertEqual(value.mapValue?["timestamp"], .int(1_704_067_200_250_000))
  }

  func testGyroscopeAndMagnetometerKeepNativeVectorUnits() {
    XCTAssertEqual(
      FletMotionSensorSemantics.vectorReading(
        x: 1.5, y: 2.5, z: 3.5, motionTimestamp: 1, bootEpoch: 1_704_067_200),
      .map([
        "x": .double(1.5), "y": .double(2.5), "z": .double(3.5),
        "timestamp": .extended(type: 1, string: "2024-01-01T00:00:01.000000+00:00"),
      ]))
  }

  func testBarometerConvertsCoreMotionKPaToFletHectopascals() {
    XCTAssertEqual(
      FletMotionSensorSemantics.barometerReading(
        pressureKilopascals: 101.325, motionTimestamp: 2, bootEpoch: 1_704_067_200),
      .map([
        "pressure": .double(1_013.25),
        "timestamp": .extended(type: 1, string: "2024-01-01T00:00:02.000000+00:00"),
      ]))
  }

  func testErrorPayloadMatchesFlet() {
    XCTAssertEqual(
      FletMotionSensorSemantics.errorEvent("Sensor unavailable"),
      .map(["message": .string("Sensor unavailable")]))
  }

  @MainActor
  func testMacOSUnavailableSensorReportsErrorOnlyWhenSubscribed() {
    #if os(macOS)
      let service = MotionSensorService(sensor: .barometer)
      var events: [(String, RufletValue)] = []
      let context = RufletServiceContext(
        store: ControlStore(),
        emitEvent: { _, name, payload in events.append((name, payload)) })
      service.activate(
        node: ControlNode(
          id: 1, type: "Barometer",
          props: ["on_error": .bool(true)]),
        context: context)
      XCTAssertEqual(events.count, 1)
      XCTAssertEqual(events.first?.0, "error")
      XCTAssertEqual(
        events.first?.1,
        .map(["message": .string("barometer is not available on this platform")]))

      // Flet update does not restart an unchanged subscription.
      service.activate(
        node: ControlNode(
          id: 1, type: "Barometer",
          props: ["on_error": .bool(true)]),
        context: context)
      XCTAssertEqual(events.count, 1)
    #endif
  }

  @MainActor
  func testSensorsAreRegistryActivatedStreamingServices() {
    let service: any RufletStreamingService = MotionSensorService(sensor: .accelerometer)
    XCTAssertTrue(service is MotionSensorService)
  }

  @MainActor
  func testFletSensorsExposeNoImperativeMethods() {
    let service = MotionSensorService(sensor: .gyroscope)
    var result: Result<RufletValue, Error>?
    service.invoke(
      RufletMethodCall(controlID: 1, callID: "test", name: "start", args: .map([:])),
      node: ControlNode(id: 1, type: "Gyroscope"),
      context: RufletServiceContext(store: ControlStore(), emitEvent: { _, _, _ in })
    ) { result = $0 }
    XCTAssertThrowsError(try result?.get())
  }
}
