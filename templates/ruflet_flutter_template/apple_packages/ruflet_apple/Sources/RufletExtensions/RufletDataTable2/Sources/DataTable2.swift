import Foundation
import RufletEngine
import RufletProtocol
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
private final class RufletTableScrollState: ObservableObject {
  @Published var horizontalOffset = 0.0
}

private struct RufletSyncedHorizontalViewport<Content: View>: View {
  @ObservedObject var state: RufletTableScrollState
  let contentWidth: Double
  let showsIndicator: Bool
  let content: Content
  @State private var dragStart = 0.0

  init(
    state: RufletTableScrollState,
    contentWidth: Double,
    showsIndicator: Bool,
    @ViewBuilder content: () -> Content
  ) {
    self.state = state
    self.contentWidth = contentWidth
    self.showsIndicator = showsIndicator
    self.content = content()
  }

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .bottomLeading) {
        content
          .frame(width: contentWidth, alignment: .leading)
          .offset(x: -min(state.horizontalOffset, maximumOffset(proxy.size.width)))
          .contentShape(Rectangle())
          .gesture(DragGesture(minimumDistance: 6)
            .onChanged { value in
              guard abs(value.translation.width) >= abs(value.translation.height) else { return }
              state.horizontalOffset = min(max(
                dragStart - value.translation.width, 0), maximumOffset(proxy.size.width))
            }
            .onEnded { _ in dragStart = state.horizontalOffset })
          .onAppear { dragStart = state.horizontalOffset }
        if showsIndicator, maximumOffset(proxy.size.width) > 0 {
          let thumbWidth = max(24, proxy.size.width * proxy.size.width / contentWidth)
          Capsule().fill(Color.secondary.opacity(0.25)).frame(height: 4)
          Capsule().fill(Color.secondary).frame(width: thumbWidth, height: 4)
            .offset(x: state.horizontalOffset / maximumOffset(proxy.size.width)
              * max(proxy.size.width - thumbWidth, 0))
        }
      }
    }
    .clipped()
  }

  private func maximumOffset(_ viewportWidth: Double) -> Double { max(contentWidth - viewportWidth, 0) }
}

@MainActor
private struct RufletDataTableHeading: View {
  let table: RufletControl
  let columns: [RufletControl]
  let widths: [Double]
  let fixedCount: Int
  let scrollState: RufletTableScrollState

  var body: some View {
    HStack(spacing: 0) {
      if displaysCheckboxColumn, table.boolean("show_heading_checkbox", default: true) {
        RufletDataTable2Checkbox(
          state: headingCheckboxState,
          enabled: true,
          theme: table.value("heading_checkbox_theme"),
          accessibilityLabel: "Select all rows",
          action: selectAll)
          .frame(width: checkboxWidth)
          .frame(maxHeight: .infinity, alignment: checkboxAlignment)
      }
      fixedColumns
      RufletSyncedHorizontalViewport(
        state: scrollState,
        contentWidth: scrollingWidth,
        showsIndicator: table.boolean("visible_horizontal_scroll_bar", default: false)
      ) {
        HStack(spacing: 0) {
          ForEach(Array(columns.dropFirst(fixedCount).enumerated()), id: \.element.id) { offset, column in
            headingCell(column, index: offset + fixedCount, width: widths[offset + fixedCount])
          }
        }
      }
    }
    .frame(height: table.number("heading_row_height", default: 56) ?? 56)
    .background(RufletTableRowDecoration(
      value: table.value("heading_row_decoration"),
      fallback: rufletTableColor(table.value("heading_row_color"), default: .clear)))
  }

  private var fixedColumns: some View {
    HStack(spacing: 0) {
      ForEach(Array(columns.prefix(fixedCount).enumerated()), id: \.element.id) { index, column in
        headingCell(column, index: index, width: widths[index])
      }
    }
    .background(parseColor(table.string("fixed_corner_color"), .clear) ?? .clear)
  }

  private func headingCell(_ column: RufletControl, index: Int, width: Double) -> some View {
    let label = column.buildTextOrWidget("label", required: true) ?? AnyView(Text(""))
    let sortAscending = table.boolean("sort_ascending", default: false)
    return HStack(spacing: 5) {
      label
      if table.integer("sort_column_index") == index {
        sortArrow
          .foregroundStyle(parseColor(table.string("sort_arrow_icon_color"), .secondary) ?? .secondary)
          .rotationEffect(sortAscending ? .zero : .degrees(180))
          .animation(
            .easeInOut(duration: rufletDataTable2Duration(
              table.value("sort_arrow_animation_duration"))),
            value: sortAscending)
      }
    }
    .padding(.horizontal, controlSpacing / 2)
    .frame(width: width, alignment: headingAlignment(column))
    .font(.system(size: headingStyle?.size ?? 14, weight: headingStyle?.weight ?? .semibold))
    .foregroundStyle(headingStyle?.color ?? .primary)
    .overlay(alignment: .trailing) { verticalDivider }
    .contentShape(Rectangle())
    .onTapGesture {
      guard column.hasEventHandler("sort") else { return }
      let ascending = table.integer("sort_column_index") == index
        ? !table.boolean("sort_ascending", default: false)
        : true
      column.triggerEvent("sort", data: .map(["ci": .int(Int64(index)), "asc": .bool(ascending)]))
    }
    .help(column.string("tooltip") ?? "")
  }

  @ViewBuilder
  private var sortArrow: some View {
    if let code = table.integer("sort_arrow_icon"),
       let icon = table.backend.extensionRegistry.appleIcon(for: code)
    {
      RufletAppleIconView.registered(icon: icon, size: 16)
    } else {
      Image(systemName: "arrow.up")
    }
  }

  private var headingStyle: RufletTextStyle? { parseTextStyle(table.value("heading_text_style")) }
  private var controlSpacing: Double { table.number("column_spacing", default: 10) ?? 10 }
  private var verticalDivider: some View {
    let side = RufletTableBorderSide(table.value("vertical_lines"))
    return Rectangle().fill(side?.color ?? .clear).frame(width: side?.width ?? 0)
  }

  private func headingAlignment(_ column: RufletControl) -> Alignment {
    switch column.string("heading_row_alignment")?.lowercased() {
    case "center": .center
    case "end", "spacebetween", "space_between": .trailing
    default: .leading
    }
  }

  private var checkboxWidth: Double {
    let margin = table.number("checkbox_horizontal_margin")
      ?? table.number("horizontal_margin", default: 24)
      ?? 24
    return 18 + margin / 2
  }
  private var checkboxAlignment: Alignment {
    parseAlignment(
      table.value("checkbox_alignment"), RufletAlignment(x: 0, y: 0))!.swiftUI
  }
  private var scrollingWidth: Double { zip(columns.dropFirst(fixedCount), widths.dropFirst(fixedCount)).reduce(0) { $0 + $1.1 } }

  private var selectableRows: [RufletControl] {
    table.children("rows", visibleOnly: false).filter { $0.hasEventHandler("select_change") }
  }
  private var displaysCheckboxColumn: Bool {
    table.boolean("show_checkbox_column", default: false) && !selectableRows.isEmpty
  }
  private var headingCheckboxState: RufletDataTable2CheckboxState {
    let selected = selectableRows.count { $0.boolean("selected", default: false) }
    if selected == 0 { return .unchecked }
    if selected == selectableRows.count { return .checked }
    return .mixed
  }
  private func selectAll() {
    let value = headingCheckboxState != .checked
    if table.hasEventHandler("select_all") {
      table.triggerEvent("select_all", data: .bool(value))
    } else {
      for row in selectableRows where row.boolean("selected", default: false) != value {
        row.triggerEvent("select_change", data: .bool(value))
      }
    }
  }
}

func rufletDataTable2Duration(_ value: RufletValue?) -> TimeInterval {
  guard let value else { return 0.000_150 }
  if case .extensionValue(let type, let payload) = value,
     type == 3,
     let text = String(data: payload, encoding: .utf8),
     let microseconds = Double(text)
  {
    return max(microseconds / 1_000_000, 0)
  }
  if let milliseconds = value.number { return max(milliseconds / 1_000, 0) }
  guard let map = value.map else { return 0.000_150 }
  return max(
    (map["days"]?.number ?? 0) * 86_400
      + (map["hours"]?.number ?? 0) * 3_600
      + (map["minutes"]?.number ?? 0) * 60
      + (map["seconds"]?.number ?? 0)
      + (map["milliseconds"]?.number ?? 0) / 1_000
      + (map["microseconds"]?.number ?? 0) / 1_000_000,
    0)
}

@MainActor
private struct RufletDataTableRow: View {
  let table: RufletControl
  let row: RufletControl
  let columns: [RufletControl]
  let widths: [Double]
  let fixedCount: Int
  let scrollState: RufletTableScrollState
  let rowIndex: Int

  var body: some View {
    HStack(spacing: 0) {
      if displaysCheckboxColumn {
        RufletDataTable2Checkbox(
          state: row.boolean("selected", default: false) ? .checked : .unchecked,
          enabled: row.hasEventHandler("select_change"),
          theme: table.value("data_row_checkbox_theme"),
          accessibilityLabel: "Select row",
          action: selectRow)
          .frame(width: checkboxWidth)
          .frame(maxHeight: .infinity, alignment: checkboxAlignment)
      }
      fixedCells
      RufletSyncedHorizontalViewport(
        state: scrollState,
        contentWidth: scrollingWidth,
        showsIndicator: table.boolean("visible_horizontal_scroll_bar", default: false)
      ) {
        HStack(spacing: 0) {
          ForEach(Array(cells.dropFirst(fixedCount).enumerated()), id: \.element.id) { offset, cell in
            dataCell(cell, column: columns[safe: offset + fixedCount], width: widths[safe: offset + fixedCount] ?? 90)
          }
        }
      }
    }
    .frame(height: row.number("specific_row_height") ?? table.number("data_row_height", default: 48) ?? 48)
    .background(rowBackground)
    .contentShape(Rectangle())
    .onTapGesture { if row.hasEventHandler("tap") { row.triggerEvent("tap") } }
    .simultaneousGesture(TapGesture(count: 2).onEnded { if row.hasEventHandler("double_tap") { row.triggerEvent("double_tap") } })
    .onLongPressGesture { if row.hasEventHandler("long_press") { row.triggerEvent("long_press") } }
    .overlay { RufletSecondaryTapSurface { point in reportSecondary(point) }.allowsHitTesting(row.hasEventHandler("secondary_tap") || row.hasEventHandler("secondary_tap_down")) }
  }

  private var cells: [RufletControl] { row.children("cells", visibleOnly: false) }

  private var fixedCells: some View {
    HStack(spacing: 0) {
      ForEach(Array(cells.prefix(fixedCount).enumerated()), id: \.element.id) { index, cell in
        dataCell(cell, column: columns[safe: index], width: widths[safe: index] ?? 90)
      }
    }
    .background(parseColor(table.string("fixed_columns_color"), .clear) ?? .clear)
  }

  private func dataCell(_ cell: RufletControl, column: RufletControl?, width: Double) -> some View {
    let content = cell.buildWidget("content") ?? AnyView(ErrorControl("DataCell content is required"))
    return HStack(spacing: 4) {
      content.opacity(cell.boolean("placeholder", default: false) ? 0.55 : 1)
      if cell.boolean("show_edit_icon", default: false) { Image(systemName: "pencil") }
    }
    .padding(.horizontal, controlSpacing / 2)
    .frame(width: width, alignment: column?.boolean("numeric", default: false) == true ? .trailing : .leading)
    .font(.system(size: dataStyle?.size ?? 14, weight: dataStyle?.weight ?? .regular))
    .foregroundStyle(dataStyle?.color ?? .primary)
    .overlay(alignment: .trailing) { verticalDivider }
    .contentShape(Rectangle())
    .onTapGesture { if cell.hasEventHandler("tap") { cell.triggerEvent("tap") } }
    .simultaneousGesture(TapGesture(count: 2).onEnded { if cell.hasEventHandler("double_tap") { cell.triggerEvent("double_tap") } })
    .onLongPressGesture { if cell.hasEventHandler("long_press") { cell.triggerEvent("long_press") } }
    .simultaneousGesture(DragGesture(minimumDistance: 0)
      .onChanged { value in
        if cell.hasEventHandler("tap_down") {
          cell.triggerEvent("tap_down", data: pointValue(value.location))
        }
      }
      .onEnded { _ in if cell.hasEventHandler("tap_cancel") { cell.triggerEvent("tap_cancel") } })
  }

  private var dataStyle: RufletTextStyle? { parseTextStyle(table.value("data_text_style")) }
  private var controlSpacing: Double { table.number("column_spacing", default: 10) ?? 10 }
  private var verticalDivider: some View {
    let side = RufletTableBorderSide(table.value("vertical_lines"))
    return Rectangle().fill(side?.color ?? .clear).frame(width: side?.width ?? 0)
  }

  private var rowBackground: Color {
    let selected = row.boolean("selected", default: false)
    let configured = rufletDataTable2StateColor(
      row.value("color"), selected: selected, fallback: .clear)
    if configured != .clear { return configured }
    return rufletDataTable2StateColor(table.value("data_row_color"), selected: selected,
      fallback: rowIndex.isMultiple(of: 2) ? Color.secondary.opacity(0.04) : .clear)
  }

  private func selectRow() {
    guard row.hasEventHandler("select_change") else { return }
    row.triggerEvent(
      "select_change", data: .bool(!row.boolean("selected", default: false)))
  }

  private var checkboxWidth: Double {
    let margin = table.number("checkbox_horizontal_margin")
      ?? table.number("horizontal_margin", default: 24)
      ?? 24
    return 18 + margin / 2
  }
  private var checkboxAlignment: Alignment {
    parseAlignment(
      table.value("checkbox_alignment"), RufletAlignment(x: 0, y: 0))!.swiftUI
  }
  private var scrollingWidth: Double { zip(columns.dropFirst(fixedCount), widths.dropFirst(fixedCount)).reduce(0) { $0 + $1.1 } }
  private var displaysCheckboxColumn: Bool {
    table.boolean("show_checkbox_column", default: false)
      && table.children("rows", visibleOnly: false).contains {
        $0.hasEventHandler("select_change")
      }
  }

  private func reportSecondary(_ point: CGPoint) {
    if row.hasEventHandler("secondary_tap_down") { row.triggerEvent("secondary_tap_down", data: pointValue(point)) }
    if row.hasEventHandler("secondary_tap") { row.triggerEvent("secondary_tap") }
  }
}

private func pointValue(_ point: CGPoint) -> RufletValue {
  .map([
    "local_x": .double(point.x), "local_y": .double(point.y),
    "global_x": .double(point.x), "global_y": .double(point.y),
  ])
}

#if os(iOS)
private struct RufletSecondaryTapSurface: UIViewRepresentable {
  let action: (CGPoint) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(action: action) }
  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.backgroundColor = .clear
    let gesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
    if #available(iOS 13.4, *) { gesture.buttonMaskRequired = .secondary }
    gesture.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)]
    view.addGestureRecognizer(gesture)
    return view
  }
  func updateUIView(_ view: UIView, context: Context) { context.coordinator.action = action }
  final class Coordinator: NSObject {
    var action: (CGPoint) -> Void
    init(action: @escaping (CGPoint) -> Void) { self.action = action }
    @objc func tapped(_ sender: UITapGestureRecognizer) { action(sender.location(in: sender.view)) }
  }
}
#elseif os(macOS)
private struct RufletSecondaryTapSurface: NSViewRepresentable {
  let action: (CGPoint) -> Void
  func makeCoordinator() -> Coordinator { Coordinator(action: action) }
  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    let gesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.clicked(_:)))
    gesture.buttonMask = 0x2
    view.addGestureRecognizer(gesture)
    return view
  }
  func updateNSView(_ view: NSView, context: Context) { context.coordinator.action = action }
  final class Coordinator: NSObject {
    var action: (CGPoint) -> Void
    init(action: @escaping (CGPoint) -> Void) { self.action = action }
    @objc func clicked(_ sender: NSClickGestureRecognizer) { action(sender.location(in: sender.view)) }
  }
}
#endif

struct DataTable2Control: View {
  @ObservedObject var control: RufletControl
  @StateObject private var scrollState = RufletTableScrollState()

  var body: some View {
    GeometryReader { proxy in
      Group {
        if rows.isEmpty, let empty = control.buildWidget("empty") {
          empty
        } else {
          table
        }
      }
      .frame(minWidth: control.number("min_width") ?? proxy.size.width)
      .padding(.horizontal, control.number("horizontal_margin", default: 24) ?? 24)
      .background(RufletTableBackground(control: control))
      .modifier(RufletDataTableClipModifier(
        behavior: control.string("clip_behavior", default: "none") ?? "none",
        radius: borderRadius))
      .overlay(RoundedRectangle(cornerRadius: borderRadius).stroke(borderColor, lineWidth: borderWidth))
    }
  }

  private var table: some View {
    ScrollView(.vertical, showsIndicators: control.boolean("visible_vertical_scroll_bar", default: true)) {
      LazyVStack(spacing: 0, pinnedViews: fixedTopRows > 0 ? [.sectionHeaders] : []) {
        Section {
          if fixedTopRows == 0 { heading }
          ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
            if fixedTopRows <= 1 || index >= fixedTopRows - 1 {
              rowView(row, index: index)
              if index < rows.count - 1 || control.boolean("show_bottom_border", default: false) {
                divider
              }
            }
          }
        } header: {
          if fixedTopRows > 0 {
            VStack(spacing: 0) {
              heading
              ForEach(Array(rows.prefix(max(fixedTopRows - 1, 0)).enumerated()), id: \.element.id) { index, row in
                rowView(row, index: index)
                if index < rows.count - 1 || control.boolean("show_bottom_border", default: false) {
                  divider
                }
              }
            }
            .background(.regularMaterial)
          }
        }
      }
      .padding(.bottom, control.number("bottom_margin", default: 0) ?? 0)
    }
  }

  private var heading: some View {
    RufletDataTableHeading(
      table: control,
      columns: columns,
      widths: widths,
      fixedCount: fixedCount,
      scrollState: scrollState)
  }

  private func rowView(_ row: RufletControl, index: Int) -> some View {
    row.notifyParent = true
    return RufletDataTableRow(
      table: control,
      row: row,
      columns: columns,
      widths: widths,
      fixedCount: fixedCount,
      scrollState: scrollState,
      rowIndex: index)
  }

  private var divider: some View {
    let side = RufletTableBorderSide(control.value("horizontal_lines"))
    return Rectangle().fill(side?.color ?? Color.secondary.opacity(0.25)).frame(height: side?.width ?? control.number("divider_thickness", default: 1) ?? 1)
  }

  private var columns: [RufletControl] {
    let result = control.children("columns", visibleOnly: false)
    for column in result { column.notifyParent = true }
    return result
  }
  private var rows: [RufletControl] { control.children("rows", visibleOnly: false) }
  private var fixedCount: Int { min(max(control.integer("fixed_left_columns", default: 0) ?? 0, 0), columns.count) }
  private var fixedTopRows: Int { max(control.integer("fixed_top_rows", default: 1) ?? 1, 0) }
  private var widths: [Double] {
    let min = max((control.number("min_width", default: 0) ?? 0) / Double(max(columns.count, 1)), 90)
    return columns.map {
      rufletDataColumnWidth(
        $0,
        minWidth: min,
        smallRatio: control.number("sm_ratio", default: 0.67) ?? 0.67,
        largeRatio: control.number("lm_ratio", default: 1.2) ?? 1.2)
    }
  }
  private var borderRadius: Double {
    control.value("border_radius")?.number ?? control.value("border_radius")?.map?["top_left"]?.number ?? 0
  }
  private var borderColor: Color {
    let map = control.value("border")?.map
    return parseColor(map?["color"]?.text, .clear) ?? .clear
  }
  private var borderWidth: Double { control.value("border")?.map?["width"]?.number ?? 0 }
}

enum RufletDataTable2CheckboxState: Equatable {
  case unchecked
  case checked
  case mixed
}

struct RufletDataTable2CheckboxStyle {
  let fill: Color
  let check: Color
  let border: Color
  let borderWidth: Double
  let cornerRadius: Double

  init(theme: RufletValue?, state: RufletDataTable2CheckboxState, enabled: Bool) {
    let map = theme?.map
    let selected = state != .unchecked
    fill = rufletDataTable2StateColor(
      map?["fill_color"], selected: selected,
      disabled: !enabled, fallback: selected ? .accentColor : .clear)
    check = rufletDataTable2StateColor(
      map?["check_color"], selected: selected,
      disabled: !enabled, fallback: .white)
    let side = map?["border_side"]?.map
    border = parseColor(side?["color"]?.text, .secondary) ?? .secondary
    borderWidth = side?["width"]?.number ?? 1
    let shape = map?["shape"]?.map
    let type = shape?["_type"]?.text?.lowercased() ?? ""
    cornerRadius = type.contains("circle")
      ? 9
      : shape?["radius"]?.number
        ?? shape?["border_radius"]?.number
        ?? 2
  }
}

func rufletDataTable2StateColor(
  _ value: RufletValue?,
  selected: Bool,
  disabled: Bool = false,
  fallback: Color
) -> Color {
  if let text = value?.text { return parseColor(text, fallback) ?? fallback }
  guard let map = value?.map else { return fallback }
  let raw = (disabled ? map["disabled"]?.text : nil)
    ?? (selected ? map["selected"]?.text : nil)
    ?? map["default"]?.text
    ?? map[""]?.text
    ?? map["any"]?.text
  return parseColor(raw, fallback) ?? fallback
}

private struct RufletDataTable2Checkbox: View {
  let state: RufletDataTable2CheckboxState
  let enabled: Bool
  let theme: RufletValue?
  let accessibilityLabel: String
  let action: () -> Void

  var body: some View {
    let style = RufletDataTable2CheckboxStyle(
      theme: theme, state: state, enabled: enabled)
    Button(action: action) {
      ZStack {
        RoundedRectangle(cornerRadius: style.cornerRadius)
          .fill(style.fill)
        RoundedRectangle(cornerRadius: style.cornerRadius)
          .stroke(style.border, lineWidth: style.borderWidth)
        if state == .checked {
          Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(style.check)
        } else if state == .mixed {
          Image(systemName: "minus")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(style.check)
        }
      }
      .frame(width: 18, height: 18)
      .opacity(enabled ? 1 : 0.45)
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityValue(
      state == .checked ? "Selected" : state == .mixed ? "Partially selected" : "Not selected")
  }
}

private struct RufletTableRowDecoration: View {
  let value: RufletValue?
  let fallback: Color

  var body: some View {
    let map = value?.map
    if let gradient = map?["gradient"]?.map,
      let colors = gradient["colors"]?.array?.compactMap({ parseColor($0.text) }),
      !colors.isEmpty
    {
      LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    } else {
      rufletTableColor(map?["color"] ?? value, default: fallback)
    }
  }
}

private struct RufletDataTableClipModifier: ViewModifier {
  let behavior: String
  let radius: Double

  @ViewBuilder
  func body(content: Content) -> some View {
    if behavior.lowercased() == "none" {
      content
    } else {
      content.clipShape(
        RoundedRectangle(cornerRadius: radius),
        style: FillStyle(
          eoFill: false,
          antialiased: behavior.lowercased().contains("antialias")))
    }
  }
}

private extension Array {
  subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
