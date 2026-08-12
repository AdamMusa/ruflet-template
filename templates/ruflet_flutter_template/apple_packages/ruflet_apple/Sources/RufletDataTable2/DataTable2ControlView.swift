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
    if let fixed = column.double("fixed_width") { return CGFloat(max(fixed, 0)) }
    switch size(of: column) {
    case .small: return mediumWidth * CGFloat(smallRatio)
    case .medium: return mediumWidth
    case .large: return mediumWidth * CGFloat(largeRatio)
    }
  }

  public func height(of row: ControlNode, fallback: CGFloat) -> CGFloat {
    CGFloat(max(row.double("specific_row_height") ?? Double(fallback), 0))
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

    if rows.isEmpty, let emptyID = node.controlID(forKey: "empty") {
      ControlView(id: emptyID, axis: .none)
    } else {
      let checkboxWidth: CGFloat = showsCheckboxes(rows, semantics)
        ? 48 + 2 * CGFloat(node.double("checkbox_horizontal_margin") ?? 0) : 0
      let spacing = CGFloat(node.double("column_spacing") ?? 56)
      let horizontalMargin = CGFloat(node.double("horizontal_margin") ?? 24)
      let available = max(
        CGFloat(semantics.minWidth ?? 0),
        size.width - 2 * horizontalMargin - checkboxWidth)
      let mediumWidth = mediumColumnWidth(
        columns: columns, semantics: semantics, available: available, spacing: spacing)
      let fixedDataRows = Array(rows.prefix(max(semantics.fixedTopRows - 1, 0)))
      let scrollingRows = Array(rows.dropFirst(fixedDataRows.count))

      VStack(alignment: .leading, spacing: 0) {
        if semantics.fixedTopRows > 0 {
          headingRow(
            columns: columns, semantics: semantics, mediumWidth: mediumWidth,
            spacing: spacing, checkboxWidth: checkboxWidth)
        }

        ForEach(fixedDataRows, id: \.id) { row in
          dataRow(
            row, columns: columns, semantics: semantics,
            mediumWidth: mediumWidth, spacing: spacing, checkboxWidth: checkboxWidth,
            isLast: row.id == rows.last?.id)
        }

        ScrollView(.vertical, showsIndicators: semantics.visibleVerticalScrollbar ?? true) {
          VStack(alignment: .leading, spacing: 0) {
            if semantics.fixedTopRows == 0 {
              headingRow(
                columns: columns, semantics: semantics, mediumWidth: mediumWidth,
                spacing: spacing, checkboxWidth: checkboxWidth)
            }
            ForEach(scrollingRows, id: \.id) { row in
              dataRow(
                row, columns: columns, semantics: semantics,
                mediumWidth: mediumWidth, spacing: spacing, checkboxWidth: checkboxWidth,
                isLast: row.id == rows.last?.id)
            }
            Color.clear.frame(height: CGFloat(semantics.bottomMargin ?? 0))
          }
        }
      }
      .frame(minWidth: CGFloat(semantics.minWidth ?? 0), alignment: .leading)
      .padding(.horizontal, horizontalMargin)
      .background(tableBackground)
      .overlay { tableBorder }
      .modifier(DataTable2ClipModifier(
        behavior: semantics.clipBehavior,
        radius: ControlProps.cornerRadius(node.props["border_radius"]) ?? 0))
    }
  }

  private func headingRow(
    columns: [ControlNode], semantics: DataTable2Semantics,
    mediumWidth: CGFloat, spacing: CGFloat, checkboxWidth: CGFloat
  ) -> some View {
    tableRow(
      columns: columns, row: nil, semantics: semantics,
      mediumWidth: mediumWidth, spacing: spacing, checkboxWidth: checkboxWidth)
      .frame(height: CGFloat(node.double("heading_row_height") ?? 56))
      .background(headingBackground)
      .rufletTextStyle(RufletTextStyle(map: node.map("heading_text_style") ?? [:]))
      .overlay(alignment: .bottom) { horizontalRule }
  }

  private func dataRow(
    _ row: ControlNode, columns: [ControlNode], semantics: DataTable2Semantics,
    mediumWidth: CGFloat, spacing: CGFloat, checkboxWidth: CGFloat, isLast: Bool
  ) -> some View {
    tableRow(
      columns: columns, row: row, semantics: semantics,
      mediumWidth: mediumWidth, spacing: spacing, checkboxWidth: checkboxWidth)
      .frame(height: semantics.height(
        of: row, fallback: CGFloat(node.double("data_row_height") ?? 48)))
      .background(rowBackground(row))
      .rufletTextStyle(RufletTextStyle(map: node.map("data_text_style") ?? [:]))
      .contentShape(Rectangle())
      .modifier(DataTable2InteractionReporter(node: row, events: events))
      .overlay(alignment: .bottom) {
        if !isLast || semantics.showBottomBorder { horizontalRule }
      }
  }

  @ViewBuilder
  private func tableRow(
    columns: [ControlNode], row: ControlNode?, semantics: DataTable2Semantics,
    mediumWidth: CGFloat, spacing: CGFloat, checkboxWidth: CGFloat
  ) -> some View {
    let fixedCount = min(semantics.fixedLeftColumns, columns.count)
    let fixed = Array(columns.prefix(fixedCount))
    let scrolling = Array(columns.dropFirst(fixedCount))

    HStack(spacing: 0) {
      if checkboxWidth > 0 {
        checkbox(row: row, semantics: semantics)
          .frame(width: checkboxWidth, alignment: checkboxAlignment)
          .background(fixedColor(row: row, corner: true))
      }
      columnsView(
        fixed, row: row, semantics: semantics,
        mediumWidth: mediumWidth, spacing: spacing)
        .background(fixedColor(row: row, corner: false))

      ScrollView(.horizontal, showsIndicators: semantics.visibleHorizontalScrollbar ?? true) {
        columnsView(
          scrolling, row: row, semantics: semantics,
          mediumWidth: mediumWidth, spacing: spacing)
      }
    }
  }

  private func columnsView(
    _ columns: [ControlNode], row: ControlNode?, semantics: DataTable2Semantics,
    mediumWidth: CGFloat, spacing: CGFloat
  ) -> some View {
    HStack(spacing: spacing) {
      ForEach(columns, id: \.id) { column in
        Group {
          if let row {
            cell(row: row, columnIndex: allColumnIndex(column))
          } else {
            header(column, index: allColumnIndex(column))
          }
        }
        .frame(width: semantics.width(of: column, mediumWidth: mediumWidth))
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
    .help(column.string("tooltip") ?? "")
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
        Image(systemName: allSelected ? "checkmark.square.fill" : "square")
      }
      .buttonStyle(.plain)
      .disabled(!node.handlesEvent("select_all"))
    }
  }

  private func selectAll() {
    events.fire(node, "select_all", data: .bool(!allSelected))
  }

  private var allSelected: Bool {
    let rows = childNodes("rows")
    return !rows.isEmpty && rows.allSatisfy { $0.bool("selected") ?? false }
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

  private func mediumColumnWidth(
    columns: [ControlNode], semantics: DataTable2Semantics,
    available: CGFloat, spacing: CGFloat
  ) -> CGFloat {
    let flexible = columns.filter { $0.double("fixed_width") == nil }
    let fixed = columns.compactMap { $0.double("fixed_width") }.reduce(0, +)
    let factors = flexible.reduce(0.0) { partial, column in
      switch semantics.size(of: column) {
      case .small: return partial + semantics.smallRatio
      case .medium: return partial + 1
      case .large: return partial + semantics.largeRatio
      }
    }
    let gaps = spacing * CGFloat(max(columns.count - 1, 0))
    return max((available - CGFloat(fixed) - gaps) / CGFloat(max(factors, 1)), 1)
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
    let requested = node.string("sort_arrow_icon")?.lowercased() ?? "arrow_upward"
    if requested.contains("down") { return "arrow.down" }
    if requested.contains("left") { return "arrow.left" }
    if requested.contains("right") { return "arrow.right" }
    return "arrow.up"
  }

  private var sortArrowAnimation: Animation? {
    let microseconds = node.double("sort_arrow_animation_duration") ?? 150
    guard microseconds > 0 else { return nil }
    return .easeInOut(duration: microseconds / 1_000_000)
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
  @State private var pointerOrigin: CGPoint?

  func body(content: Content) -> some View {
    content
      .onTapGesture(count: 2) { events.fire(node, "double_tap") }
      .onTapGesture(count: 1) { events.fire(node, "tap") }
      .onLongPressGesture { events.fire(node, "long_press") }
      .simultaneousGesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
          .onChanged { value in
            guard pointerOrigin == nil else { return }
            pointerOrigin = value.startLocation
            events.fire(node, "tap_down", data: Self.tapPayload(value.startLocation))
          }
          .onEnded { value in
            defer { pointerOrigin = nil }
            guard let origin = pointerOrigin else { return }
            if hypot(value.location.x - origin.x, value.location.y - origin.y) > 18 {
              events.fire(node, "tap_cancel")
            }
          })
      .background(secondaryPointerMonitor)
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

  private static func tapPayload(_ point: CGPoint) -> RufletValue {
    .map([
      "local_x": .double(Double(point.x)), "local_y": .double(Double(point.y)),
      "kind": .string("touch"),
    ])
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
        let payload: RufletValue = .map([
          "local_x": .double(Double(point.x)), "local_y": .double(Double(point.y)),
          "kind": .string("mouse"),
        ])
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
