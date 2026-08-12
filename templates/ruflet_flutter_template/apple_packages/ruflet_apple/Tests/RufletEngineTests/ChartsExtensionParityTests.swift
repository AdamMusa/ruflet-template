@testable import RufletCharts
@testable import RufletUI
import RufletEngine
import XCTest

@MainActor
final class ChartsExtensionParityTests: XCTestCase {
  private let chartTypes = [
    "LineChart", "BarChart", "PieChart", "ScatterChart", "RadarChart",
    "CandlestickChart",
  ]

  func testEveryFletChartKeepsItsOptionalProductBoundaryInCore() {
    for wireType in chartTypes {
      let descriptor = ControlRegistry.builtInDescriptor(for: wireType)
      XCTAssertEqual(descriptor?.classification, .visible)
      XCTAssertEqual(descriptor?.rendering, .optionalBundle("RufletCharts"))
      XCTAssertEqual(descriptor?.implementation, "RufletCharts.ChartControlView")
      XCTAssertEqual(descriptor?.supportedEvents, ["event"])
    }
  }

  func testRegisteringChartsInstallsAllSixNativePainters() {
    let services = ServiceRegistry()
    services.register(extension: RufletCharts.self)

    XCTAssertTrue(services.hasExtension("RufletCharts"))
    for wireType in chartTypes {
      let descriptor = ControlRegistry.descriptor(for: wireType)
      XCTAssertEqual(descriptor?.rendering, .nativeView)
      XCTAssertEqual(descriptor?.implementation, "RufletCharts.ChartControlView")
      XCTAssertNotNil(
        ControlRegistry.build(
          node: ControlNode(id: 1, type: wireType, props: [:]), axis: .none))
    }
  }

  func testManifestMarksFletChartsAvailable() {
    let charts = RufletExtensionManifest.packages.first { $0.fletPackage == "flet_charts" }
    XCTAssertEqual(charts?.swiftProduct, "RufletCharts")
    XCTAssertEqual(charts?.status, .available)
  }
}
