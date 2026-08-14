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
  let content: Content
  @State private var dragStart = 0.0

  init(
    state: RufletTableScrollState,
    contentWidth: Double,
    @ViewBuilder content: () -> Content
  ) {
    self.state = state
    self.contentWidth = contentWidth
    self.content = content()
  }

  var body: some View {
    GeometryReader { proxy in
      content
        .frame(width: contentWidth, alignment: .leading)
        .offset(x: -min(state.horizontalOffset, maximumOffset(proxy.size.width)))
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 6)
          .onChanged { value in
            guard abs(value.translation.width) >= abs(value.translation.height) else { return }
            state.horizontalOffset = min(max(dragStart - value.translation.width, 0), maximumOffset(proxy.size.width))
          }
          .onEnded { _ in dragStart = state.horizontalOffset })
        .onAppear { dragStart = state.horizontalOffset }
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
      if table.boolean("show_checkbox_column", default: false), table.boolean("show_heading_checkbox", default: true) {
        Toggle("", isOn: selectAllBinding).labelsHidden().frame(width: checkboxWidth)
      }
      fixedColumns
      RufletSyncedHorizontalViewport(state: scrollState, contentWidth: scrollingWidth) {
        HStack(spacing: 0) {
          ForEach(Array(columns.dropFirst(fixedCount).enumerated()), id: \.element.id) { offset, column in
            headingCell(column, index: offset + fixedCount, width: widths[offset + fixedCount])
          }
        }
      }
    }
    .frame(height: table.number("heading_row_height", default: 56) ?? 56)
    .background(rufletTableColor(table.value("heading_row_color"), default: .clear))
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

  private var checkboxWidth: Double { table.number("checkbox_horizontal_margin", default: 48) ?? 48 }
  private var scrollingWidth: Double { zip(columns.dropFirst(fixedCount), widths.dropFirst(fixedCount)).reduce(0) { $0 + $1.1 } }

  private var selectAllBinding: Binding<Bool> {
    Binding(
      get: {
        let rows = table.children("rows", visibleOnly: false)
        return !rows.isEmpty && rows.allSatisfy { $0.boolean("selected", default: false) }
      },
      set: { table.triggerEvent("select_all", data: .bool($0)) })
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
      if table.boolean("show_checkbox_column", default: false) {
        Toggle("", isOn: selectionBinding).labelsHidden().frame(width: checkboxWidth)
      }
      fixedCells
      RufletSyncedHorizontalViewport(state: scrollState, contentWidth: scrollingWidth) {
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
    let configured = rufletTableColor(row.value("color"), default: .clear)
    if configured != .clear { return configured }
    return rowIndex.isMultiple(of: 2) ? Color.secondary.opacity(0.04) : .clear
  }

  private var selectionBinding: Binding<Bool> {
    Binding(
      get: { row.boolean("selected", default: false) },
      set: { row.triggerEvent("select_change", data: .bool($0)) })
  }

  private var checkboxWidth: Double { table.number("checkbox_horizontal_margin", default: 48) ?? 48 }
  private var scrollingWidth: Double { zip(columns.dropFirst(fixedCount), widths.dropFirst(fixedCount)).reduce(0) { $0 + $1.1 } }

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
      .background(RufletTableBackground(control: control))
      .clipShape(RoundedRectangle(cornerRadius: borderRadius))
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
              divider
            }
          }
        } header: {
          if fixedTopRows > 0 {
            VStack(spacing: 0) {
              heading
              ForEach(Array(rows.prefix(max(fixedTopRows - 1, 0)).enumerated()), id: \.element.id) { index, row in
                rowView(row, index: index)
                divider
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

private extension Array {
  subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
