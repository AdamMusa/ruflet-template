import RufletEngine
import RufletProtocol
import RufletUI
import SwiftUI

#if os(macOS)
  import AppKit
#endif

/// Source-defined behavior from Flet's vendored `flet_datatable2` adapter.
/// These are control defaults, not Explorer-specific presentation values.
public struct DataTable2Semantics: Equatable {
  public enum ColumnSize: String, Equatable {
    case small = "s"
    case medium = "m"
    case large = "l"
  }

  public let fixedLeftColumns: Int
  public let fixedTopRows: Int
  public let smallRatio: Double
  public let largeRatio: Double
  public let showHeadingCheckbox: Bool
  public let showBottomBorder: Bool
  public let showCheckboxColumn: Bool
  public let sortAscending: Bool
  public let checkboxAlignment: String
  public let visibleHorizontalScrollbar: Bool?
  public let visibleVerticalScrollbar: Bool?
  public let minWidth: Double?
  public let bottomMargin: Double?
  public let clipBehavior: String

  public init(_ node: ControlNode) {
    fixedLeftColumns = max(node.int("fixed_left_columns") ?? 0, 0)
    fixedTopRows = max(node.int("fixed_top_rows") ?? 1, 0)
    smallRatio = node.double("sm_ratio") ?? 0.67
    largeRatio = node.double("lm_ratio") ?? 1.2
    showHeadingCheckbox = node.bool("show_heading_checkbox") ?? true
    showBottomBorder = node.bool("show_bottom_border") ?? false
    showCheckboxColumn = node.bool("show_checkbox_column") ?? false
    sortAscending = node.bool("sort_ascending") ?? false
    checkboxAlignment = node.string("checkbox_alignment") ?? "center"
    visibleHorizontalScrollbar = node.bool("visible_horizontal_scroll_bar")
    visibleVerticalScrollbar = node.bool("visible_vertical_scroll_bar")
    minWidth = node.double("min_width")
    bottomMargin = node.double("bottom_margin")
    clipBehavior = node.string("clip_behavior") ?? "none"
  }

  public func size(of column: ControlNode) -> ColumnSize {
    ColumnSize(rawValue: column.string("size")?.lowercased() ?? "") ?? .small
  }

  public func width(of column: ControlNode, mediumWidth: CGFloat) -> CGFloat {
    if let fixed = column.double("fixed_width") { return CGFloat(fixed) }
    switch size(of: column) {
    case .small: return mediumWidth * CGFloat(smallRatio)
    case .medium: return mediumWidth
    case .large: return mediumWidth * CGFloat(largeRatio)
    }
  }

  public func height(of row: ControlNode, fallback: CGFloat) -> CGFloat {
    CGFloat(row.double("specific_row_height") ?? Double(fallback))
  }
}

/// The width algorithm from `data_table_2` 2.6.0's
/// `_calculateDataColumnSizes`. Widths include the cell's leading/trailing
/// padding, just as Flutter table column widths do; treating `column_spacing`
/// as an HStack gap changes both fixed-column boundaries and min-width
/// scrolling.
public struct DataTable2LayoutMetrics: Equatable {
  public struct FixedPartition: Equatable {
    public let checkboxIsFixed: Bool
    public let fixedDataColumnCount: Int

    public init(checkboxIsFixed: Bool, fixedDataColumnCount: Int) {
      self.checkboxIsFixed = checkboxIsFixed
      self.fixedDataColumnCount = fixedDataColumnCount
    }
  }

  public static let materialCheckboxWidth: CGFloat = 18

  public let horizontalMargin: CGFloat
  public let checkboxHorizontalMargin: CGFloat?
  public let columnSpacing: CGFloat
  public let minWidth: CGFloat?
  public let smallRatio: CGFloat
  public let largeRatio: CGFloat

  public init(_ node: ControlNode) {
    horizontalMargin = CGFloat(node.double("horizontal_margin") ?? 24)
    checkboxHorizontalMargin = node.double("checkbox_horizontal_margin").map { CGFloat($0) }
    columnSpacing = CGFloat(node.double("column_spacing") ?? 56)
    minWidth = node.double("min_width").map { CGFloat($0) }
    smallRatio = CGFloat(node.double("sm_ratio") ?? 0.67)
    largeRatio = CGFloat(node.double("lm_ratio") ?? 1.2)
  }

  public func checkboxWidth(visible: Bool) -> CGFloat {
    guard visible else { return 0 }
    let margin = checkboxHorizontalMargin ?? horizontalMargin
    return margin + Self.materialCheckboxWidth + margin / 2
  }

  public func cellPadding(columnIndex: Int, columnCount: Int, checkboxVisible: Bool)
    -> (leading: CGFloat, trailing: CGFloat)
  {
    let leading = columnIndex == 0
      ? (checkboxVisible ? horizontalMargin / 2 : horizontalMargin)
      : columnSpacing / 2
    let trailing = columnIndex == columnCount - 1 ? horizontalMargin : columnSpacing / 2
    return (leading, trailing)
  }

  public func columnWidths(
    availableWidth: CGFloat, columns: [ControlNode], checkboxVisible: Bool
  ) -> [CGFloat] {
    guard !columns.isEmpty else { return [] }
    let checkbox = checkboxWidth(visible: checkboxVisible)
    var available = max(availableWidth, minWidth ?? availableWidth)
    available -= checkbox
    available -= horizontalMargin
    available -= checkboxVisible ? horizontalMargin / 2 : horizontalMargin

    let base = available / CGFloat(columns.count)
    let fixedTotal = columns.compactMap { $0.double("fixed_width") }.reduce(0, +)
    let flexibleAvailable = max(0, available - CGFloat(fixedTotal))
    var calculatedFlexible: CGFloat = 0
    var widths = columns.map { column -> CGFloat in
      if let fixed = column.double("fixed_width") { return CGFloat(fixed) }
      let size = column.string("size")?.lowercased() ?? "s"
      let width = base * (size == "l" ? largeRatio : size == "m" ? 1 : smallRatio)
      calculatedFlexible += width
      return width
    }

    if calculatedFlexible != 0 {
      let scale = flexibleAvailable / calculatedFlexible
      for index in widths.indices where columns[index].double("fixed_width") == nil {
        widths[index] *= scale
      }
    }

    if widths.count == 1 {
      widths[0] = max(
        0, widths[0] + horizontalMargin + (checkboxVisible ? horizontalMargin / 2 : horizontalMargin))
    } else {
      widths[0] = max(
        0, widths[0] + (checkboxVisible ? horizontalMargin / 2 : horizontalMargin))
      widths[widths.count - 1] = max(0, widths[widths.count - 1] + horizontalMargin)
    }
    return widths
  }

  /// `data_table_2` counts the checkbox as the first fixed column. It also
  /// disables all sticky columns when there are no data rows, even though the
  /// heading remains visible.
  public func fixedPartition(
    columnCount: Int, rowsAreEmpty: Bool, checkboxDeclared: Bool,
    checkboxVisible: Bool, fixedLeftColumns: Int
  ) -> FixedPartition {
    let actualFixed = rowsAreEmpty
      ? 0
      : min(max(fixedLeftColumns, 0), columnCount + (checkboxDeclared ? 1 : 0))
    let checkboxIsFixed = checkboxVisible && actualFixed > 0
    return FixedPartition(
      checkboxIsFixed: checkboxIsFixed,
      fixedDataColumnCount: min(
        columnCount, max(actualFixed - (checkboxIsFixed ? 1 : 0), 0)))
  }
}

public enum DataTable2SelectionSemantics {
  /// Mirrors `_handleSelectAll`: an indeterminate heading checkbox selects
  /// all rows; only an entirely selected table clears them.
  public static func nextSelectAllValue(rows: [ControlNode]) -> Bool {
    let selectable = rows.filter { $0.handlesEvent("select_change") }
    let allSelected = !selectable.isEmpty && selectable.allSatisfy { $0.bool("selected") == true }
    return !allSelected
  }

  public static func fallbackRowChanges(rows: [ControlNode], selected: Bool)
    -> [(id: Int, selected: Bool)]
  {
    rows.compactMap { row in
      guard row.handlesEvent("select_change"), row.bool("selected") != selected else { return nil }
      return (row.id, selected)
    }
  }
}

public enum DataTable2EventPayload {
  /// Flet's `TapDownDetails.toMap()` wire shape (`k`, `l`, `g`).
  public static func tapDown(kind: String, local: CGPoint, global: CGPoint) -> RufletValue {
    .map([
      "k": .string(kind),
      "l": .map(["x": .double(Double(local.x)), "y": .double(Double(local.y))]),
      "g": .map(["x": .double(Double(global.x)), "y": .double(Double(global.y))]),
    ])
  }
}

public enum DataTable2ColumnSemantics {
  public static func tooltipMessage(_ column: ControlNode) -> String? {
    if let value = column.string("tooltip") { return value }
    return column.map("tooltip")?["message"]?.stringValue
  }

  public static func sortArrowSymbol(_ table: ControlNode) -> String {
    IconMapping.symbol(for: table.props["sort_arrow_icon"]) ?? "arrow.up"
  }

  /// The vendored adapter's fallback is intentionally 150 microseconds (not
  /// data_table_2's constructor default of 150 milliseconds).
  public static func sortArrowDurationSeconds(_ table: ControlNode) -> Double {
    guard let value = table.props["sort_arrow_animation_duration"], !value.isNull else {
      return 150 / 1_000_000
    }
    // Flet's `parseDuration` treats a bare number as milliseconds.
    if let number = value.doubleValue { return number / 1_000 }
    guard let fields = value.mapValue else { return 150 / 1_000_000 }
    return Double(fields["days"]?.intValue ?? 0) * 86_400
      + Double(fields["hours"]?.intValue ?? 0) * 3_600
      + Double(fields["minutes"]?.intValue ?? 0) * 60
      + Double(fields["seconds"]?.intValue ?? 0)
      + Double(fields["milliseconds"]?.intValue ?? 0) / 1_000
      + Double(fields["microseconds"]?.intValue ?? 0) / 1_000_000
  }
}

public struct DataTable2ControlView: View {
  public let node: ControlNode
  @EnvironmentObject private var store: ControlStore
  @Environment(\.rufletEvents) private var events

  public init(node: ControlNode) { self.node = node }

  public var body: some View {
    GeometryReader { proxy in
      table(in: proxy.size)
    }
  }

  @ViewBuilder
  private func table(in size: CGSize) -> some View {
    let columns = childNodes("columns")
    let rows = childNodes("rows")
    let semantics = DataTable2Semantics(node)
    let layout = DataTable2LayoutMetrics(node)
    let checkboxVisible = showsCheckboxes(rows, semantics)
    let checkboxWidth = layout.checkboxWidth(visible: checkboxVisible)
    let widths = layout.columnWidths(
      availableWidth: size.width, columns: columns, checkboxVisible: checkboxVisible)
    let fixedDataRows = Array(rows.prefix(max(semantics.fixedTopRows - 1, 0)))
    let scrollingRows = Array(rows.dropFirst(fixedDataRows.count))

    VStack(alignment: .leading, spacing: 0) {
      if semantics.fixedTopRows > 0 {
        headingRow(
          columns: columns, semantics: semantics, widths: widths,
          checkboxWidth: checkboxWidth, checkboxVisible: checkboxVisible)
      }

      ForEach(fixedDataRows, id: \.id) { row in
        dataRow(
          row, columns: columns, semantics: semantics, widths: widths,
          checkboxWidth: checkboxWidth, checkboxVisible: checkboxVisible,
          isLast: row.id == rows.last?.id)
      }

      ScrollView(.vertical, showsIndicators: semantics.visibleVerticalScrollbar ?? true) {
        VStack(alignment: .leading, spacing: 0) {
          if semantics.fixedTopRows == 0 {
            headingRow(
              columns: columns, semantics: semantics, widths: widths,
              checkboxWidth: checkboxWidth, checkboxVisible: checkboxVisible)
          }
          ForEach(scrollingRows, id: \.id) { row in
            dataRow(
              row, columns: columns, semantics: semantics, widths: widths,
              checkboxWidth: checkboxWidth, checkboxVisible: checkboxVisible,
              isLast: row.id == rows.last?.id)
          }
          if rows.isEmpty, let emptyID = node.controlID(forKey: "empty") {
            ControlView(id: emptyID, axis: .vertical)
              .frame(maxWidth: .infinity, minHeight: max(size.height - 56, 0))
          }
          Color.clear.frame(height: CGFloat(semantics.bottomMargin ?? 0))
        }
      }
    }
    .frame(minWidth: CGFloat(semantics.minWidth ?? 0), alignment: .leading)
    .background(tableBackground)
    .overlay { tableBorder }
    .modifier(DataTable2ClipModifier(
      behavior: semantics.clipBehavior,
      radius: ControlProps.cornerRadius(node.props["border_radius"]) ?? 0))
  }

  private func headingRow(
    columns: [ControlNode], semantics: DataTable2Semantics,
    widths: [CGFloat], checkboxWidth: CGFloat, checkboxVisible: Bool
  ) -> some View {
    tableRow(
      columns: columns, row: nil, semantics: semantics,
      widths: widths, checkboxWidth: checkboxWidth, checkboxVisible: checkboxVisible)
      .frame(height: CGFloat(node.double("heading_row_height") ?? 56))
      .background(headingBackground)
      .rufletTextStyle(RufletTextStyle(map: node.map("heading_text_style") ?? [:]))
      .overlay(alignment: .bottom) { horizontalRule }
  }

  private func dataRow(
    _ row: ControlNode, columns: [ControlNode], semantics: DataTable2Semantics,
    widths: [CGFloat], checkboxWidth: CGFloat, checkboxVisible: Bool, isLast: Bool
  ) -> some View {
    tableRow(
      columns: columns, row: row, semantics: semantics,
      widths: widths, checkboxWidth: checkboxWidth, checkboxVisible: checkboxVisible)
      .frame(height: semantics.height(
        of: row, fallback: CGFloat(node.double("data_row_height") ?? 48)))
      .background(rowBackground(row))
      .rufletTextStyle(RufletTextStyle(map: node.map("data_text_style") ?? [:]))
      .contentShape(Rectangle())
      .modifier(DataTable2InteractionReporter(
        node: row, events: events,
        selectsRowOnTap: row.handlesEvent("select_change") && !row.handlesEvent("tap")))
      .overlay(alignment: .bottom) {
        if !isLast || semantics.showBottomBorder { horizontalRule }
      }
  }

  @ViewBuilder
  private func tableRow(
    columns: [ControlNode], row: ControlNode?, semantics: DataTable2Semantics,
    widths: [CGFloat], checkboxWidth: CGFloat, checkboxVisible: Bool
  ) -> some View {
    let partition = DataTable2LayoutMetrics(node).fixedPartition(
      columnCount: columns.count, rowsAreEmpty: childNodes("rows").isEmpty,
      checkboxDeclared: semantics.showCheckboxColumn, checkboxVisible: checkboxVisible,
      fixedLeftColumns: semantics.fixedLeftColumns)
    let checkboxIsFixed = partition.checkboxIsFixed
    let fixedDataCount = partition.fixedDataColumnCount
    let fixed = Array(columns.prefix(fixedDataCount))
    let scrolling = Array(columns.dropFirst(fixedDataCount))

    HStack(spacing: 0) {
      if checkboxIsFixed {
        checkbox(row: row, semantics: semantics)
          .frame(width: checkboxWidth, alignment: checkboxAlignment)
          .background(fixedColor(row: row, corner: true))
      }
      columnsView(
        fixed, row: row, semantics: semantics,
        widths: widths, checkboxVisible: checkboxVisible)
        .background(fixedColor(row: row, corner: false))

      ScrollView(.horizontal, showsIndicators: semantics.visibleHorizontalScrollbar ?? true) {
        HStack(spacing: 0) {
          if checkboxVisible && !checkboxIsFixed {
            checkbox(row: row, semantics: semantics)
              .frame(width: checkboxWidth, alignment: checkboxAlignment)
          }
          columnsView(
            scrolling, row: row, semantics: semantics,
            widths: widths, checkboxVisible: checkboxVisible)
        }
      }
    }
  }

  private func columnsView(
    _ columns: [ControlNode], row: ControlNode?, semantics: DataTable2Semantics,
    widths: [CGFloat], checkboxVisible: Bool
  ) -> some View {
    HStack(spacing: 0) {
      ForEach(columns, id: \.id) { column in
        let index = allColumnIndex(column)
        let padding = DataTable2LayoutMetrics(node).cellPadding(
          columnIndex: index, columnCount: widths.count, checkboxVisible: checkboxVisible)
        Group {
          if let row {
            cell(row: row, columnIndex: index)
          } else {
            header(column, index: index)
          }
        }
        .padding(.leading, padding.leading)
        .padding(.trailing, padding.trailing)
        .frame(width: widths.indices.contains(index) ? widths[index] : 0)
        .overlay(alignment: .trailing) { verticalRule }
      }
    }
  }

  @ViewBuilder
  private func header(_ column: ControlNode, index: Int) -> some View {
    Button {
      let ascending = node.int("sort_column_index") == index
        ? !(node.bool("sort_ascending") ?? false) : true
      events.fire(column, "sort", data: .map(["ci": .int(Int64(index)), "asc": .bool(ascending)]))
    } label: {
      HStack(spacing: 4) {
        content(column, key: "label")
        if node.int("sort_column_index") == index {
          Image(systemName: sortArrowName)
            .foregroundColor(MaterialPalette.color(node.string("sort_arrow_icon_color")))
            .rotationEffect((node.bool("sort_ascending") ?? false) ? .zero : .degrees(180))
            .animation(sortArrowAnimation, value: node.bool("sort_ascending") ?? false)
        }
      }
      .frame(maxWidth: .infinity, alignment: headingAlignment(column))
    }
    .buttonStyle(.plain)
    .help(DataTable2ColumnSemantics.tooltipMessage(column) ?? "")
    .disabled(!column.handlesEvent("sort"))
  }

  @ViewBuilder
  private func cell(row: ControlNode, columnIndex: Int) -> some View {
    let cells = childNodes("cells", from: row)
    if cells.indices.contains(columnIndex) {
      let cell = cells[columnIndex]
      content(cell, key: "content")
        .opacity(cell.bool("placeholder") == true ? 0.55 : 1)
        .overlay(alignment: .trailing) {
          if cell.bool("show_edit_icon") == true { Image(systemName: "pencil") }
        }
        .contentShape(Rectangle())
        .modifier(DataTable2InteractionReporter(node: cell, events: events))
    }
  }

  @ViewBuilder
  private func content(_ owner: ControlNode, key: String) -> some View {
    if let id = owner.controlID(forKey: key) {
      ControlView(id: id, axis: .none)
    } else {
      Text(owner.string(key) ?? "")
    }
  }

  @ViewBuilder
  private func checkbox(row: ControlNode?, semantics: DataTable2Semantics) -> some View {
    if let row {
      Button {
        let selected = !(row.bool("selected") ?? false)
        events.setLocal(row.id, "selected", .bool(selected))
        events.fire(row, "select_change", data: .bool(selected))
      } label: {
        Image(systemName: row.bool("selected") == true ? "checkmark.square.fill" : "square")
      }
      .buttonStyle(.plain)
      .disabled(!row.handlesEvent("select_change"))
    } else if semantics.showHeadingCheckbox {
      Button { selectAll() } label: {
        Image(systemName: headingCheckboxSymbol)
      }
      .buttonStyle(.plain)
      // DataTable2 falls back to invoking each selectable row when an
      // explicit `onSelectAll` callback is absent.
      .disabled(!node.handlesEvent("select_all") && selectableRows.isEmpty)
    }
  }

  private func selectAll() {
    let selected = DataTable2SelectionSemantics.nextSelectAllValue(rows: childNodes("rows"))
    if node.handlesEvent("select_all") {
      events.fire(node, "select_all", data: .bool(selected))
      return
    }
    for change in DataTable2SelectionSemantics.fallbackRowChanges(
      rows: childNodes("rows"), selected: selected)
    {
      guard let row = store.node(change.id) else { continue }
      events.setLocal(row.id, "selected", .bool(change.selected))
      events.fire(row, "select_change", data: .bool(change.selected))
    }
  }

  private var allSelected: Bool {
    !selectableRows.isEmpty && selectableRows.allSatisfy { $0.bool("selected") ?? false }
  }

  private var someSelected: Bool {
    selectableRows.contains { $0.bool("selected") == true } && !allSelected
  }

  private var selectableRows: [ControlNode] {
    childNodes("rows").filter { $0.handlesEvent("select_change") }
  }

  private var headingCheckboxSymbol: String {
    if someSelected { return "minus.square.fill" }
    return allSelected ? "checkmark.square.fill" : "square"
  }

  private func showsCheckboxes(_ rows: [ControlNode], _ semantics: DataTable2Semantics) -> Bool {
    semantics.showCheckboxColumn && rows.contains { $0.handlesEvent("select_change") }
  }

  private func childNodes(_ key: String, from owner: ControlNode? = nil) -> [ControlNode] {
    (owner ?? node).controlIDs(forKey: key).compactMap { store.node($0) }
  }

  private func allColumnIndex(_ column: ControlNode) -> Int {
    childNodes("columns").firstIndex { $0.id == column.id } ?? 0
  }

  private var checkboxAlignment: Alignment {
    ControlProps.alignment(node.props["checkbox_alignment"]) ?? .center
  }

  private func headingAlignment(_ column: ControlNode) -> Alignment {
    switch column.string("heading_row_alignment")?.lowercased().replacingOccurrences(of: "_", with: "") {
    case "center": return .center
    case "end", "spacearound", "spacebetween", "spaceevenly": return .trailing
    default: return column.bool("numeric") == true ? .trailing : .leading
    }
  }

  private var sortArrowName: String {
    DataTable2ColumnSemantics.sortArrowSymbol(node)
  }

  private var sortArrowAnimation: Animation? {
    let seconds = DataTable2ColumnSemantics.sortArrowDurationSeconds(node)
    guard seconds > 0 else { return nil }
    return .easeInOut(duration: seconds)
  }

  private func rowColor(_ row: ControlNode) -> Color {
    if let explicit = MaterialPalette.color(row.string("color")) { return explicit }
    let state = node.map("data_row_color")
    if row.bool("selected") == true {
      return MaterialPalette.color(state?["selected"]?.stringValue, default: .clear)
    }
    return MaterialPalette.color(state?["default"]?.stringValue, default: .clear)
  }

  @ViewBuilder
  private func rowBackground(_ row: ControlNode) -> some View {
    if let decoration = row.map("decoration") {
      DataTable2Decoration(map: decoration, fallback: rowColor(row))
    } else {
      rowColor(row)
    }
  }

  private func fixedColor(row: ControlNode?, corner: Bool) -> Color {
    MaterialPalette.color(
      node.string(corner && row == nil ? "fixed_corner_color" : "fixed_columns_color"),
      default: row.map(rowColor) ?? .clear)
  }

  @ViewBuilder
  private var tableBackground: some View {
    if let gradient = GradientProps.linear(node.props["gradient"]) {
      gradient
    } else {
      MaterialPalette.color(node.string("bgcolor"), default: .clear)
    }
  }

  @ViewBuilder
  private var headingBackground: some View {
    if let decoration = node.map("heading_row_decoration") {
      DataTable2Decoration(
        map: decoration,
        fallback: MaterialPalette.color(node.string("heading_row_color"), default: .clear))
    } else {
      MaterialPalette.color(node.string("heading_row_color"), default: .clear)
    }
  }

  @ViewBuilder private var horizontalRule: some View {
    if let side = node.map("horizontal_lines") {
      Rectangle().fill(MaterialPalette.color(side["color"]?.stringValue, default: .clear))
        .frame(height: CGFloat(side["width"]?.doubleValue ?? 1))
    } else if (node.double("divider_thickness") ?? 1) > 0 {
      Divider().frame(height: CGFloat(node.double("divider_thickness") ?? 1))
    }
  }

  @ViewBuilder private var verticalRule: some View {
    if let side = node.map("vertical_lines") {
      Rectangle().fill(MaterialPalette.color(side["color"]?.stringValue, default: .clear))
        .frame(width: CGFloat(side["width"]?.doubleValue ?? 1))
    }
  }

  @ViewBuilder private var tableBorder: some View {
    if let border = node.map("border") {
      RoundedRectangle(cornerRadius: ControlProps.cornerRadius(node.props["border_radius"]) ?? 0)
        .stroke(
          MaterialPalette.color(border["color"]?.stringValue, default: .clear),
          lineWidth: CGFloat(border["width"]?.doubleValue ?? 1))
    }
  }
}

private struct DataTable2Decoration: View {
  let map: [String: RufletValue]
  let fallback: Color

  var body: some View {
    let radius = ControlProps.cornerRadius(map["border_radius"]) ?? 0
    RoundedRectangle(cornerRadius: radius)
      .fill(background)
      .overlay {
        if let border = map["border"]?.mapValue {
          RoundedRectangle(cornerRadius: radius)
            .stroke(
              MaterialPalette.color(border["color"]?.stringValue, default: .clear),
              lineWidth: CGFloat(border["width"]?.doubleValue ?? 1))
        }
      }
  }

  private var background: AnyShapeStyle {
    if let gradient = GradientProps.linear(map["gradient"]) {
      return AnyShapeStyle(gradient)
    }
    return AnyShapeStyle(MaterialPalette.color(map["color"]?.stringValue, default: fallback))
  }
}

private struct DataTable2ClipModifier: ViewModifier {
  let behavior: String
  let radius: CGFloat

  func body(content: Content) -> some View {
    if behavior.lowercased() == "none" {
      content
    } else {
      content.clipShape(RoundedRectangle(cornerRadius: radius))
    }
  }
}

private struct DataTable2InteractionReporter: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  var selectsRowOnTap = false

  func body(content: Content) -> some View {
    content
      .modifier(DataTable2OptionalTap(
        enabled: node.handlesEvent("tap") || selectsRowOnTap,
        count: 1,
        action: {
          if node.handlesEvent("tap") {
            events.fire(node, "tap")
          } else if selectsRowOnTap {
            let selected = !(node.bool("selected") ?? false)
            events.setLocal(node.id, "selected", .bool(selected))
            events.fire(node, "select_change", data: .bool(selected))
          }
        }))
      .modifier(DataTable2OptionalTap(
        enabled: node.handlesEvent("double_tap"), count: 2,
        action: { events.fire(node, "double_tap") }))
      .modifier(DataTable2OptionalLongPress(
        enabled: node.handlesEvent("long_press"),
        action: { events.fire(node, "long_press") }))
      .modifier(DataTable2OptionalTapDown(
        node: node, events: events,
        enabled: node.handlesEvent("tap_down") || node.handlesEvent("tap_cancel")))
      .background {
        if node.handlesEvent("secondary_tap") || node.handlesEvent("secondary_tap_down") {
          secondaryPointerMonitor
        }
      }
  }

  @ViewBuilder private var secondaryPointerMonitor: some View {
    #if os(macOS)
      DataTable2SecondaryPointerMonitor { name, payload in
        events.fire(node, name, data: payload)
      }
    #else
      EmptyView()
    #endif
  }

}

private struct DataTable2OptionalTap: ViewModifier {
  let enabled: Bool
  let count: Int
  let action: () -> Void

  @ViewBuilder func body(content: Content) -> some View {
    if enabled { content.onTapGesture(count: count, perform: action) } else { content }
  }
}

private struct DataTable2OptionalLongPress: ViewModifier {
  let enabled: Bool
  let action: () -> Void

  @ViewBuilder func body(content: Content) -> some View {
    if enabled { content.onLongPressGesture(perform: action) } else { content }
  }
}

private struct DataTable2OptionalTapDown: ViewModifier {
  let node: ControlNode
  let events: RufletEventSink
  let enabled: Bool
  @State private var pointerOrigin: CGPoint?

  @ViewBuilder func body(content: Content) -> some View {
    if enabled {
      content.simultaneousGesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
          .onChanged { value in
            guard pointerOrigin == nil else { return }
            pointerOrigin = value.startLocation
            if node.handlesEvent("tap_down") {
              events.fire(node, "tap_down", data: DataTable2EventPayload.tapDown(
                kind: "touch", local: value.startLocation, global: value.startLocation))
            }
          }
          .onEnded { value in
            defer { pointerOrigin = nil }
            guard node.handlesEvent("tap_cancel"), let origin = pointerOrigin else { return }
            if hypot(value.location.x - origin.x, value.location.y - origin.y) > 18 {
              events.fire(node, "tap_cancel")
            }
          })
    } else {
      content
    }
  }
}

#if os(macOS)
  private struct DataTable2SecondaryPointerMonitor: NSViewRepresentable {
    let onEvent: (String, RufletValue) -> Void

    func makeNSView(context: Context) -> MonitorView {
      let view = MonitorView()
      view.onEvent = onEvent
      return view
    }

    func updateNSView(_ view: MonitorView, context: Context) { view.onEvent = onEvent }

    final class MonitorView: NSView {
      var onEvent: (String, RufletValue) -> Void = { _, _ in }
      private var monitor: Any?
      private var start: CGPoint?
      override func hitTest(_ point: NSPoint) -> NSView? { nil }

      override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor { NSEvent.removeMonitor(monitor) }
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(
          matching: [.rightMouseDown, .rightMouseUp, .rightMouseDragged]
        ) { [weak self] event in
          self?.handle(event)
          return event
        }
      }

      deinit { if let monitor { NSEvent.removeMonitor(monitor) } }

      private func handle(_ event: NSEvent) {
        guard let window, event.window === window else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return }
        let payload = DataTable2EventPayload.tapDown(
          kind: "mouse", local: point, global: event.locationInWindow)
        switch event.type {
        case .rightMouseDown:
          start = point
          onEvent("secondary_tap_down", payload)
        case .rightMouseUp:
          if let start, hypot(point.x - start.x, point.y - start.y) <= 18 {
            onEvent("secondary_tap", .null)
          }
          self.start = nil
        case .rightMouseDragged:
          break
        default:
          break
        }
      }
    }
  }
#endif
