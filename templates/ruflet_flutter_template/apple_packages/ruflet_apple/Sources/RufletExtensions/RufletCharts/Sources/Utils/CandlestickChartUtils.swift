import RufletEngine

struct CandlestickSpot: Identifiable {
  let id: Int
  let x: Double
  let open: Double
  let high: Double
  let low: Double
  let close: Double
  let selected: Bool

  @MainActor static func parse(_ control: RufletControl) -> Self {
    control.notifyParent = true
    return Self(
      id: control.id,
      x: control.number("x", default: 0) ?? 0,
      open: control.number("open", default: 0) ?? 0,
      high: control.number("high", default: 0) ?? 0,
      low: control.number("low", default: 0) ?? 0,
      close: control.number("close", default: 0) ?? 0,
      selected: control.boolean("selected", default: false))
  }
}

struct CandlestickChartEventData: Equatable {
  let eventType: String
  let spotIndex: Int?
  let spotX: Double?
  let spotOpen: Double?
  let spotHigh: Double?
  let spotLow: Double?
  let spotClose: Double?
}
