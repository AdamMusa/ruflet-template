import Foundation
import RufletProtocol
import SwiftUI
import Testing
@testable import RufletColorPickers
@testable import RufletDataTable2

@Suite("Pinned optional-control compound defaults")
struct CompoundDefaultParityTests {
  @Test("DataTable2 retains Flet's exact 150-microsecond sort animation")
  func dataTableSortAnimation() {
    #expect(rufletDataTable2Duration(nil) == 0.000_150)
    #expect(rufletDataTable2Duration(
      .extensionValue(type: 3, payload: Data("250000".utf8))) == 0.25)
    #expect(rufletDataTable2Duration(.map(["milliseconds": .int(25)])) == 0.025)
  }

  @Test("SlidePicker size defaults preserve both dimensions")
  func slidePickerSizes() {
    let slider = rufletSlidePickerSize(nil, default: CGSize(width: 260, height: 40))
    let indicator = rufletSlidePickerSize(nil, default: CGSize(width: 280, height: 50))
    #expect(slider == CGSize(width: 260, height: 40))
    #expect(indicator == CGSize(width: 280, height: 50))
  }

  @Test("SlidePicker retains Flet's out-of-bounds gradient alignment")
  func slidePickerAlignment() {
    let begin = rufletSlidePickerAlignment(nil, defaultX: -1, defaultY: -3)
    let end = rufletSlidePickerAlignment(nil, defaultX: 1, defaultY: 3)
    #expect(begin.x == 0)
    #expect(begin.y == -1)
    #expect(end.x == 1)
    #expect(end.y == 2)
  }
}
