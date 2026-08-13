import RufletEngine
import SwiftUI

@MainActor
public struct RufletChartsExtension: RufletExtension {
  public init() {}

  public var renderedControlTypes: Set<String> { RufletCharts.controlTypes }

  public func createView(for control: RufletControl) -> AnyView? {
    switch control.type {
    case "BarChart": AnyView(BarChartControl(control: control))
    case "CandlestickChart": AnyView(CandlestickChartControl(control: control))
    case "LineChart": AnyView(LineChartControl(control: control))
    case "PieChart": AnyView(PieChartControl(control: control))
    case "RadarChart": AnyView(RadarChartControl(control: control))
    case "ScatterChart": AnyView(ScatterChartControl(control: control))
    default: nil
    }
  }
}
