@testable import RufletUI
import RufletProtocol
import XCTest

final class DisplayPluginParityTests: XCTestCase {
  func testDisplayEventsUseFletWireNames() {
    XCTAssertEqual(events("Text"), ["selection_change", "tap"])
    XCTAssertEqual(events("CircleAvatar"), ["image_error"])
    XCTAssertEqual(events("Markdown"), ["selection_change", "tap_link", "tap_text"])
    XCTAssertEqual(events("Lottie"), ["error", "load"])
    XCTAssertEqual(events("Rive"), [])
  }

  func testCanvasAndChartsAdvertiseFletCommandsAndEvents() {
    XCTAssertEqual(events("Canvas"), ["resize"])
    XCTAssertEqual(methods("Canvas"), ["capture", "clear_capture", "get_capture"])
    for type in ["BarChart", "CandlestickChart", "LineChart", "PieChart", "RadarChart",
                 "ScatterChart"] {
      XCTAssertEqual(events(type), ["event"], type)
    }
  }

  func testAnimationPluginsAreNativeViews() {
    for type in ["Lottie", "Rive", "RufletSpinKit"] {
      let descriptor = ControlRegistry.builtInDescriptor(for: type)
      XCTAssertEqual(descriptor?.classification, .visible)
      XCTAssertEqual(descriptor?.rendering, .nativeView)
    }
  }

  func testCanvasCaptureBufferReturnsFletBinaryAndClearsIt() {
    var capture = CanvasCaptureBuffer()
    XCTAssertEqual(capture.wireValue, .null)

    capture.store(Data([0x89, 0x50, 0x4E, 0x47]))
    XCTAssertEqual(capture.wireValue, .binary([0x89, 0x50, 0x4E, 0x47]))

    capture.clear()
    XCTAssertEqual(capture.wireValue, .null)
  }

  private func events(_ type: String) -> Set<String> {
    ControlRegistry.builtInDescriptor(for: type)?.supportedEvents ?? []
  }

  private func methods(_ type: String) -> Set<String> {
    ControlRegistry.builtInDescriptor(for: type)?.supportedMethods ?? []
  }
}
