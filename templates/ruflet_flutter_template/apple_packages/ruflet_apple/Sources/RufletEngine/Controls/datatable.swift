import RufletProtocol
import SwiftUI

@MainActor
struct RufletDataTableStructure {
  let columns: [RufletControl]
  let rows: [RufletControl]
  private let cellsByRowID: [Int: [RufletControl]]

  init(control: RufletControl) {
    columns = control.children("columns")
    rows = control.children("rows")
    for column in columns { column.notifyParent = true }

    var cells: [Int: [RufletControl]] = [:]
    for row in rows {
      row.notifyParent = true
      let visibleCells = row.children("cells")
      for cell in visibleCells { cell.notifyParent = true }
      cells[row.id] = visibleCells
    }
    cellsByRowID = cells
  }

  func cells(for row: RufletControl) -> [RufletControl] {
    cellsByRowID[row.id] ?? []
  }

  var invalidRow: RufletControl? {
    rows.first { cells(for: $0).count != columns.count }
  }
}

struct RufletDataTableMetrics {
  let columnSpacing: CGFloat
  let horizontalMargin: CGFloat
  let headingRowHeight: CGFloat
  let dataRowMinHeight: CGFloat
  let dataRowMaxHeight: CGFloat
  let dividerThickness: CGFloat
  let checkboxMarginStart: CGFloat
  let checkboxMarginEnd: CGFloat

  @MainActor
  init(table: RufletControl) {
    columnSpacing = CGFloat(max(table.number("column_spacing", default: 56)!, 0))
    horizontalMargin = CGFloat(max(table.number("horizontal_margin", default: 24)!, 0))
    headingRowHeight = CGFloat(max(table.number("heading_row_height", default: 56)!, 0))
    dataRowMinHeight = CGFloat(max(table.number("data_row_min_height", default: 48)!, 0))
    dataRowMaxHeight = CGFloat(
      max(table.number("data_row_max_height", default: 48)!, Double(dataRowMinHeight)))
    dividerThickness = CGFloat(max(table.number("divider_thickness", default: 1)!, 0))
    if let margin = table.number("checkbox_horizontal_margin") {
      checkboxMarginStart = CGFloat(max(margin, 0))
      checkboxMarginEnd = CGFloat(max(margin, 0))
    } else {
      checkboxMarginStart = horizontalMargin
      checkboxMarginEnd = horizontalMargin / 2
    }
  }

  func cellPadding(
    column: Int,
    columnCount: Int,
    checkboxVisible: Bool
  ) -> EdgeInsets {
    EdgeInsets(
      top: 0,
      leading: column == 0
        ? (checkboxVisible ? horizontalMargin / 2 : horizontalMargin) : columnSpacing / 2,
      bottom: 0,
      trailing: column == columnCount - 1 ? horizontalMargin : columnSpacing / 2)
  }

  var checkboxColumnWidth: CGFloat {
    checkboxMarginStart + 20 + checkboxMarginEnd
  }
}

@MainActor
func rufletSortDataTableColumn(
  _ column: RufletControl,
  index: Int,
  table: RufletControl
) {
  guard column.boolean("on_sort", default: false) else { return }
  let ascending =
    table.integer("sort_column_index") == index
    ? !table.boolean("sort_ascending", default: false)
    : true
  column.triggerEvent(
    "sort",
    data: .map(["ci": .int(Int64(index)), "asc": .bool(ascending)]))
}

@MainActor
func rufletSelectDataTableRow(_ row: RufletControl, selected: Bool) {
  guard row.boolean("on_select_change", default: false) else { return }
  row.triggerEvent("select_change", data: .bool(selected))
}

@MainActor
func rufletSelectAllDataTableRows(_ table: RufletControl, selected: Bool) {
  if table.boolean("on_select_all", default: false) {
    table.triggerEvent("select_all", data: .bool(selected))
    return
  }
  for row in table.children("rows")
  where row.boolean("selected", default: false) != selected {
    rufletSelectDataTableRow(row, selected: selected)
  }
}

@MainActor
func rufletDataCellOverridesRowInteraction(_ cell: RufletControl) -> Bool {
  ["tap", "double_tap", "long_press", "tap_cancel", "tap_down"]
    .contains { cell.boolean("on_\($0)", default: false) }
}

@MainActor
func rufletDataColumnTooltip(_ column: RufletControl) -> String? {
  if let tooltip = column.child("tooltip", visibleOnly: false) {
    return tooltip.string("message")
  }
  if let text = column.string("tooltip") { return text }
  return rufletDictionary(column.dynamicValue("tooltip"))?["message"] as? String
}

func rufletDataTableTapDetails(
  local: CGPoint,
  global: CGPoint,
  kind: String
) -> RufletValue {
  .map([
    "k": .string(kind),
    "l": .map(["x": .double(local.x), "y": .double(local.y)]),
    "g": .map(["x": .double(global.x), "y": .double(global.y)]),
  ])
}

@MainActor
func rufletDataTableHorizontalLines(_ table: RufletControl) -> RufletBorderSide? {
  // Preserve the exact property spelling consumed by pinned Flet 0.80.5.
  parseBorderSide(table.dynamicValue("horizontal_lLines"))
}

/// Apple-native port of pinned Flet `datatable.dart`.
@MainActor
public struct DataTableControl: View {
  @ObservedObject public var control: RufletControl

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    let structure = RufletDataTableStructure(control: control)
    LayoutControl(control: control) {
      if structure.columns.isEmpty {
        ErrorControl("DataTable must have at least one visible column")
      } else if let invalidRow = structure.invalidRow {
        ErrorControl(
          "DataTable row has an invalid cell count",
          description:
            "Row \(invalidRow.id) has \(structure.cells(for: invalidRow).count) visible cells for \(structure.columns.count) visible columns"
        )
      } else {
        table(structure)
      }
    }
  }

  private func table(_ structure: RufletDataTableStructure) -> some View {
    VStack(spacing: 0) {
      RufletDataTableHeadingView(table: control, structure: structure)
      internalHorizontalDivider
      ForEach(Array(structure.rows.enumerated()), id: \.element.id) { index, row in
        RufletDataTableRowView(
          table: control,
          row: row,
          columns: structure.columns,
          cells: structure.cells(for: row))
        if index < structure.rows.count - 1 || control.boolean("show_bottom_border", default: false)
        {
          internalHorizontalDivider
        }
      }
    }
    .background(RufletDataTableBackground(control: control, radius: borderRadius))
    .overlay {
      if let border {
        RufletBorderOverlay(border: border, radius: borderRadius)
      }
    }
    .modifier(
      RufletDataTableClipModifier(
        behavior: control.string("clip_behavior", default: "none")!,
        radius: borderRadius)
    )
    .accessibilityElement(children: .contain)
  }

  private var internalHorizontalDivider: some View {
    let side = horizontalLines
    return Rectangle()
      .fill(side?.color ?? Color.secondary.opacity(0.25))
      .frame(height: side?.width ?? metrics.dividerThickness)
  }

  private var horizontalLines: RufletBorderSide? {
    rufletDataTableHorizontalLines(control)
  }
  private var metrics: RufletDataTableMetrics { RufletDataTableMetrics(table: control) }
  private var border: RufletBorder? { parseBorder(control.dynamicValue("border")) }
  private var borderRadius: RufletBorderRadius {
    parseBorderRadius(control.dynamicValue("border_radius"), .zero)!
  }
}

@MainActor
private struct RufletDataTableHeadingView: View {
  @ObservedObject var table: RufletControl
  let structure: RufletDataTableStructure

  var body: some View {
    HStack(spacing: 0) {
      if showsCheckboxColumn {
        RufletDataTableCheckbox(
          state: headingCheckboxState,
          enabled: !selectableRows.isEmpty,
          label: "Select all rows"
        ) {
          rufletSelectAllDataTableRows(table, selected: !allRowsSelected)
        }
        .frame(width: checkboxColumnWidth)
      }
      HStack(spacing: 0) {
        ForEach(Array(structure.columns.enumerated()), id: \.element.id) { index, column in
          headingCell(column, index: index)
        }
      }
      .frame(maxWidth: .infinity)
    }
    .frame(height: metrics.headingRowHeight)
    .background(headingColor)
    .modifier(
      RufletTextStyleModifier(style: parseTextStyle(table.dynamicValue("heading_text_style"))))
  }

  private func headingCell(_ column: RufletControl, index: Int) -> some View {
    let sortable = column.boolean("on_sort", default: false)
    return Button {
      rufletSortDataTableColumn(column, index: index, table: table)
    } label: {
      RufletDataTableHeadingLabel(
        column: column,
        sorted: table.integer("sort_column_index") == index,
        ascending: table.boolean("sort_ascending", default: false),
        padding: metrics.cellPadding(
          column: index,
          columnCount: structure.columns.count,
          checkboxVisible: showsCheckboxColumn)
      )
      .frame(
        minWidth: column.boolean("numeric", default: false) ? 72 : 96,
        maxWidth: .infinity,
        alignment: headingAlignment(column)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!sortable)
    .help(rufletDataColumnTooltip(column) ?? "")
    .overlay(alignment: .trailing) {
      if index < structure.columns.count - 1 { verticalDivider }
    }
  }

  private var headingColor: Color {
    let states = Set<RufletWidgetState>()
    return RufletWidgetStateProperty<Color>(
      table.dynamicValue("heading_row_color"),
      converter: { parseColor($0 as? String) },
      defaultValue: .clear
    ).resolve(states) ?? .clear
  }
  private var selectableRows: [RufletControl] {
    structure.rows.filter { $0.boolean("on_select_change", default: false) }
  }
  private var showsCheckboxColumn: Bool {
    table.boolean("show_checkbox_column", default: false) && !selectableRows.isEmpty
  }
  private var allRowsSelected: Bool {
    !selectableRows.isEmpty && selectableRows.allSatisfy { $0.boolean("selected", default: false) }
  }
  private var headingCheckboxState: RufletDataTableCheckboxState {
    let selectedCount = selectableRows.filter { $0.boolean("selected", default: false) }.count
    if selectedCount == 0 { return .unchecked }
    if selectedCount == selectableRows.count { return .checked }
    return .mixed
  }
  private var checkboxColumnWidth: CGFloat {
    metrics.checkboxColumnWidth
  }
  private var verticalDivider: some View {
    let side = parseBorderSide(table.dynamicValue("vertical_lines"))
    return Rectangle().fill(side?.color ?? .clear).frame(width: side?.width ?? 0)
  }
  private func headingAlignment(_ column: RufletControl) -> Alignment {
    switch column.string("heading_row_alignment")?.lowercased() {
    case "center": return .center
    case "end", "spacebetween", "space_between": return .trailing
    case "start": return .leading
    default: return column.boolean("numeric", default: false) ? .trailing : .leading
    }
  }
  private var metrics: RufletDataTableMetrics { RufletDataTableMetrics(table: table) }
}

@MainActor
private struct RufletDataTableHeadingLabel: View {
  @ObservedObject var column: RufletControl
  let sorted: Bool
  let ascending: Bool
  let padding: EdgeInsets

  var body: some View {
    HStack(spacing: 6) {
      column.buildTextOrWidget("label", required: true)
      if sorted {
        Image(systemName: "arrow.up")
          .imageScale(.small)
          .rotationEffect(ascending ? .zero : .degrees(180))
      }
    }
    .padding(padding)
    .padding(.vertical, 6)
  }
}

@MainActor
private struct RufletDataTableRowView: View {
  @ObservedObject var table: RufletControl
  @ObservedObject var row: RufletControl
  let columns: [RufletControl]
  let cells: [RufletControl]

  var body: some View {
    HStack(spacing: 0) {
      if showsCheckboxColumn {
        Group {
          if row.boolean("on_select_change", default: false) {
            RufletDataTableCheckbox(
              state: row.boolean("selected", default: false) ? .checked : .unchecked,
              enabled: true,
              label: "Select row"
            ) {
              rufletSelectDataTableRow(
                row, selected: !row.boolean("selected", default: false))
            }
          }
        }
        .frame(width: checkboxColumnWidth)
      }
      HStack(spacing: 0) {
        ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
          dataCell(cell, column: columns[index], index: index)
        }
      }
      .frame(maxWidth: .infinity)
    }
    .frame(minHeight: metrics.dataRowMinHeight, maxHeight: metrics.dataRowMaxHeight)
    .background(rowColor)
    .modifier(RufletTextStyleModifier(style: parseTextStyle(table.dynamicValue("data_text_style"))))
  }

  private func dataCell(
    _ cell: RufletControl,
    column: RufletControl,
    index: Int
  ) -> some View {
    HStack(spacing: 5) {
      cell.buildTextOrWidget("content", required: true)
        .opacity(cell.boolean("placeholder", default: false) ? 0.55 : 1)
      if cell.boolean("show_edit_icon", default: false) {
        Image(systemName: "pencil")
          .imageScale(.small)
          .accessibilityHidden(true)
      }
    }
    .padding(
      metrics.cellPadding(
        column: index,
        columnCount: columns.count,
        checkboxVisible: showsCheckboxColumn)
    )
    .padding(.vertical, 6)
    .frame(
      minWidth: column.boolean("numeric", default: false) ? 72 : 96,
      maxWidth: .infinity,
      alignment: column.boolean("numeric", default: false) ? .trailing : .leading
    )
    .contentShape(Rectangle())
    .modifier(RufletDataTableCellInteractionModifier(cell: cell, row: row))
    .overlay(alignment: .trailing) {
      if index < cells.count - 1 { verticalDivider }
    }
  }

  private var rowColor: Color {
    var states = Set<RufletWidgetState>()
    if row.boolean("selected", default: false) { states.insert(.selected) }
    if !row.boolean("on_select_change", default: false) { states.insert(.disabled) }
    let own = RufletWidgetStateProperty<Color>(
      row.dynamicValue("color"), converter: { parseColor($0 as? String) }
    ).resolve(states)
    let inherited = RufletWidgetStateProperty<Color>(
      table.dynamicValue("data_row_color"), converter: { parseColor($0 as? String) }
    ).resolve(states)
    return own ?? inherited ?? .clear
  }
  private var showsCheckboxColumn: Bool {
    table.boolean("show_checkbox_column", default: false)
      && table.children("rows").contains { $0.boolean("on_select_change", default: false) }
  }
  private var checkboxColumnWidth: CGFloat {
    metrics.checkboxColumnWidth
  }
  private var verticalDivider: some View {
    let side = parseBorderSide(table.dynamicValue("vertical_lines"))
    return Rectangle().fill(side?.color ?? .clear).frame(width: side?.width ?? 0)
  }
  private var metrics: RufletDataTableMetrics { RufletDataTableMetrics(table: table) }
}

private enum RufletDataTableCheckboxState {
  case unchecked
  case checked
  case mixed
}

private struct RufletDataTableCheckbox: View {
  let state: RufletDataTableCheckboxState
  let enabled: Bool
  let label: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: imageName)
        .font(.system(size: 18, weight: .regular))
        .foregroundStyle(enabled ? Color.accentColor : Color.secondary)
        .frame(width: 24, height: 24)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .accessibilityLabel(label)
    .accessibilityValue(accessibilityValue)
  }

  private var imageName: String {
    switch state {
    case .unchecked: return "square"
    case .checked: return "checkmark.square.fill"
    case .mixed: return "minus.square.fill"
    }
  }
  private var accessibilityValue: String {
    switch state {
    case .unchecked: return "Not selected"
    case .checked: return "Selected"
    case .mixed: return "Partially selected"
    }
  }
}

@MainActor
private struct RufletDataTableCellInteractionModifier: ViewModifier {
  @ObservedObject var cell: RufletControl
  @ObservedObject var row: RufletControl
  @State private var frameOrigin = CGPoint.zero
  @State private var tapDownSent = false
  @State private var tapCancelled = false

  func body(content: Content) -> some View {
    tapped(content)
      .highPriorityGesture(
        LongPressGesture().onEnded { _ in
          if enabled("long_press") {
            cell.triggerEvent("long_press")
          } else if !overridesRow, row.boolean("on_long_press", default: false) {
            row.triggerEvent("long_press")
          }
        },
        including: handlesLongPress ? .all : .none
      )
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            if !tapDownSent, enabled("tap_down") {
              tapDownSent = true
              let global = CGPoint(
                x: frameOrigin.x + value.location.x,
                y: frameOrigin.y + value.location.y)
              cell.triggerEvent(
                "tap_down",
                data: rufletDataTableTapDetails(
                  local: value.location,
                  global: global,
                  kind: pointerKind))
            }
            if hypot(value.translation.width, value.translation.height) > 12 {
              tapCancelled = true
            }
          }
          .onEnded { _ in
            if tapCancelled, enabled("tap_cancel") { cell.triggerEvent("tap_cancel") }
            tapDownSent = false
            tapCancelled = false
          }
      )
      .background {
        GeometryReader { proxy in
          Color.clear.preference(
            key: RufletDataTableFrameOriginKey.self,
            value: proxy.frame(in: .global).origin)
        }
      }
      .onPreferenceChange(RufletDataTableFrameOriginKey.self) { frameOrigin = $0 }
  }

  @ViewBuilder
  private func tapped(_ content: Content) -> some View {
    let tap = enabled("tap")
    let doubleTap = enabled("double_tap")
    if tap && doubleTap {
      content.highPriorityGesture(
        ExclusiveGesture(TapGesture(count: 2), TapGesture(count: 1))
          .onEnded { result in
            switch result {
            case .first: cell.triggerEvent("double_tap")
            case .second: cell.triggerEvent("tap")
            }
          })
    } else if doubleTap {
      content.highPriorityGesture(
        TapGesture(count: 2).onEnded { cell.triggerEvent("double_tap") })
    } else if tap {
      content.highPriorityGesture(TapGesture().onEnded { cell.triggerEvent("tap") })
    } else if overridesRow {
      content.highPriorityGesture(TapGesture().onEnded {})
    } else if row.boolean("on_select_change", default: false) {
      content.highPriorityGesture(
        TapGesture().onEnded {
          rufletSelectDataTableRow(
            row, selected: !row.boolean("selected", default: false))
        })
    } else {
      content
    }
  }

  private func enabled(_ event: String) -> Bool {
    cell.boolean("on_\(event)", default: false)
  }

  private var overridesRow: Bool { rufletDataCellOverridesRowInteraction(cell) }
  private var handlesLongPress: Bool {
    enabled("long_press") || (!overridesRow && row.boolean("on_long_press", default: false))
  }

  private var pointerKind: String {
    #if os(macOS)
      "mouse"
    #else
      "touch"
    #endif
  }
}

private struct RufletDataTableFrameOriginKey: PreferenceKey {
  static var defaultValue = CGPoint.zero
  static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
    value = nextValue()
  }
}

@MainActor
private struct RufletDataTableBackground: View {
  @ObservedObject var control: RufletControl
  let radius: RufletBorderRadius

  var body: some View {
    Group {
      if let gradient = parseGradient(control.dynamicValue("gradient")) {
        RufletGradientShapeStyle(gradient: gradient)
      } else {
        parseColor(control.string("bgcolor")) ?? .clear
      }
    }
    .clipShape(RufletCornerShape(radius: radius))
  }
}

private struct RufletDataTableClipModifier: ViewModifier {
  let behavior: String
  let radius: RufletBorderRadius

  @ViewBuilder
  func body(content: Content) -> some View {
    if behavior.lowercased() == "none" {
      content
    } else {
      content.clipShape(
        RufletCornerShape(radius: radius),
        style: FillStyle(antialiased: behavior.lowercased().contains("antialias")))
    }
  }
}
