import RufletProtocol
import SwiftUI

#if os(iOS)
import UIKit
#endif

/// Apple-native port of pinned `cupertino_picker.dart`.
@MainActor
public struct CupertinoPickerControl: View {
  @ObservedObject public var control: RufletControl
  @State private var selectedIndex: Int
  @EnvironmentObject private var registry: RufletExtensionRegistry

  public init(control: RufletControl) {
    self.control = control
    _selectedIndex = State(initialValue: control.integer("selected_index", default: 0) ?? 0)
  }

  public var body: some View {
    let configuration = RufletCupertinoPickerConfiguration(control: control)

    LayoutControl(control: control) {
      ZStack {
        picker(configuration: configuration)
        selectionOverlay(configuration: configuration)
          .allowsHitTesting(false)
      }
      .frame(minHeight: configuration.itemExtent * 5)
      .background(parseColor(control.string("bgcolor")) ?? .clear)
      .clipped()
    }
    .onChange(of: selectedIndex, perform: selected)
    .onChange(of: control.properties) { _ in synchronizeFromControl() }
  }

  @ViewBuilder
  private func picker(configuration: RufletCupertinoPickerConfiguration) -> some View {
    #if os(iOS)
    RufletNativeCupertinoPicker(
      controls: controls,
      selectedIndex: $selectedIndex,
      configuration: configuration,
      registry: registry,
      disabled: control.disabled
    )
    #elseif os(macOS)
    RufletDesktopCupertinoPicker(
      controls: controls,
      selectedIndex: $selectedIndex,
      configuration: configuration
    )
    .disabled(control.disabled)
    #endif
  }

  @ViewBuilder
  private func selectionOverlay(configuration: RufletCupertinoPickerConfiguration) -> some View {
    if let overlay = control.buildWidget("selection_overlay") {
      overlay
    } else {
      RoundedRectangle(cornerRadius: 8)
        .fill(
          parseColor(control.string("default_selection_overlay_bgcolor"))
            ?? .secondary.opacity(0.14)
        )
        .frame(height: configuration.itemExtent)
        .padding(.horizontal, 8)
    }
  }

  private func selected(_ index: Int) {
    guard controls.indices.contains(index), control.integer("selected_index") != index else {
      return
    }
    control.updateProperties(["selected_index": .int(Int64(index))])
    control.triggerEvent("change", data: .int(Int64(index)))
  }

  private func synchronizeFromControl() {
    let requested = control.integer("selected_index", default: 0) ?? 0
    let clamped = controls.isEmpty ? 0 : min(max(requested, 0), controls.count - 1)
    if selectedIndex != clamped { selectedIndex = clamped }
  }

  private var controls: [RufletControl] { control.children("controls") }
}

/// Exact pinned wire defaults plus the index projection needed by Apple's
/// finite `UIPickerView` data source when Flet requests an infinite wheel.
struct RufletCupertinoPickerConfiguration: Equatable {
  static let loopingCopies = 1_001
  static let defaultSqueeze = 1.45

  let diameterRatio: Double
  let looping: Bool
  let magnification: Double
  let offAxisFraction: Double
  let squeeze: Double
  let useMagnifier: Bool
  let itemExtent: CGFloat

  @MainActor
  init(control: RufletControl) {
    diameterRatio = control.number("diameter_ratio", default: 1.07) ?? 1.07
    looping = control.boolean("looping", default: false)
    magnification = control.number("magnification", default: 1) ?? 1
    offAxisFraction = control.number("off_axis_fraction", default: 0) ?? 0
    squeeze = control.number("squeeze", default: Self.defaultSqueeze) ?? Self.defaultSqueeze
    useMagnifier = control.boolean("use_magnifier", default: false)
    itemExtent = CGFloat(control.number("item_extent", default: 32) ?? 32)

    precondition(diameterRatio > 0, "diameter_ratio must be greater than zero")
    precondition(magnification > 0, "magnification must be greater than zero")
    precondition(squeeze > 0, "squeeze must be greater than zero")
    precondition(itemExtent > 0, "item_extent must be greater than zero")
  }

  var rowPitch: CGFloat {
    itemExtent * CGFloat(Self.defaultSqueeze / squeeze)
  }

  func rowCount(for itemCount: Int) -> Int {
    guard itemCount > 0 else { return 0 }
    return looping ? itemCount * Self.loopingCopies : itemCount
  }

  func itemIndex(forRow row: Int, itemCount: Int) -> Int? {
    guard itemCount > 0 else { return nil }
    let remainder = row % itemCount
    return remainder >= 0 ? remainder : remainder + itemCount
  }

  func initialRow(selectedIndex: Int, itemCount: Int) -> Int {
    guard itemCount > 0 else { return 0 }
    let selected = min(max(selectedIndex, 0), itemCount - 1)
    guard looping else { return selected }
    return itemCount * (Self.loopingCopies / 2) + selected
  }

  func nearestRow(selectedIndex: Int, to currentRow: Int, itemCount: Int) -> Int {
    guard looping, itemCount > 0 else {
      return initialRow(selectedIndex: selectedIndex, itemCount: itemCount)
    }
    let selected = min(max(selectedIndex, 0), itemCount - 1)
    let currentIndex = itemIndex(forRow: currentRow, itemCount: itemCount) ?? 0
    var delta = selected - currentIndex
    if delta > itemCount / 2 { delta -= itemCount }
    if delta < -(itemCount / 2) { delta += itemCount }
    return min(max(currentRow + delta, 0), rowCount(for: itemCount) - 1)
  }

  func scale(forDistance distance: Int) -> CGFloat {
    if distance == 0, useMagnifier { return CGFloat(magnification) }
    let angularDistance = Double(abs(distance)) * squeeze / diameterRatio * 0.12
    return CGFloat(max(0.68, cos(min(angularDistance, .pi / 2))))
  }

  func horizontalOffset(availableWidth: CGFloat) -> CGFloat {
    CGFloat(offAxisFraction) * availableWidth / 2
  }
}

#if os(iOS)
private struct RufletNativeCupertinoPicker: UIViewRepresentable {
  let controls: [RufletControl]
  @Binding var selectedIndex: Int
  let configuration: RufletCupertinoPickerConfiguration
  let registry: RufletExtensionRegistry
  let disabled: Bool

  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

  func makeUIView(context: Context) -> UIPickerView {
    let picker = UIPickerView()
    picker.dataSource = context.coordinator
    picker.delegate = context.coordinator
    picker.backgroundColor = .clear
    context.coordinator.install(parent: self, in: picker, initial: true)
    return picker
  }

  func updateUIView(_ picker: UIPickerView, context: Context) {
    context.coordinator.install(parent: self, in: picker, initial: false)
    picker.isUserInteractionEnabled = !disabled
  }

  @MainActor
  final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    private var parent: RufletNativeCupertinoPicker
    private var renderedIDs: [Int] = []
    private var renderedConfiguration: RufletCupertinoPickerConfiguration?
    private var currentRow = 0
    private var hosts: [Int: UIHostingController<AnyView>] = [:]

    init(parent: RufletNativeCupertinoPicker) {
      self.parent = parent
    }

    func install(parent: RufletNativeCupertinoPicker, in picker: UIPickerView, initial: Bool) {
      self.parent = parent
      let ids = parent.controls.map(\.id)
      let requiresReload = ids != renderedIDs || renderedConfiguration != parent.configuration
      if requiresReload {
        renderedIDs = ids
        renderedConfiguration = parent.configuration
        hosts.removeAll()
        picker.reloadAllComponents()
      }

      guard !parent.controls.isEmpty else { return }
      let desired = initial
        ? parent.configuration.initialRow(
          selectedIndex: parent.selectedIndex,
          itemCount: parent.controls.count)
        : parent.configuration.nearestRow(
          selectedIndex: parent.selectedIndex,
          to: currentRow,
          itemCount: parent.controls.count)
      if initial || desired != currentRow || requiresReload {
        currentRow = desired
        picker.selectRow(desired, inComponent: 0, animated: false)
        picker.reloadAllComponents()
      }
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
      parent.configuration.rowCount(for: parent.controls.count)
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
      parent.configuration.rowPitch
    }

    func pickerView(
      _ pickerView: UIPickerView,
      widthForComponent component: Int
    ) -> CGFloat {
      pickerView.bounds.width
    }

    func pickerView(
      _ pickerView: UIPickerView,
      viewForRow row: Int,
      forComponent component: Int,
      reusing view: UIView?
    ) -> UIView {
      guard
        let itemIndex = parent.configuration.itemIndex(
          forRow: row,
          itemCount: parent.controls.count)
      else { return UIView() }

      let root = AnyView(
        ControlWidget(control: parent.controls[itemIndex])
          .environmentObject(parent.registry)
          .frame(maxWidth: .infinity, alignment: .center)
          .scaleEffect(parent.configuration.scale(forDistance: row - currentRow))
          .offset(
            x: parent.configuration.horizontalOffset(availableWidth: pickerView.bounds.width))
      )
      let host = hosts[row] ?? UIHostingController(rootView: root)
      host.rootView = root
      host.view.backgroundColor = .clear
      hosts[row] = host
      return host.view
    }

    func pickerView(
      _ pickerView: UIPickerView,
      didSelectRow row: Int,
      inComponent component: Int
    ) {
      currentRow = row
      guard
        let index = parent.configuration.itemIndex(
          forRow: row,
          itemCount: parent.controls.count)
      else { return }
      parent.selectedIndex = index
      pickerView.reloadAllComponents()
    }
  }
}
#endif

#if os(macOS)
private struct RufletDesktopCupertinoPicker: View {
  let controls: [RufletControl]
  @Binding var selectedIndex: Int
  let configuration: RufletCupertinoPickerConfiguration

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(displayedRows.enumerated()), id: \.offset) { offset, index in
        Button {
          selectedIndex = index
        } label: {
          ControlWidget(control: controls[index])
            .frame(maxWidth: .infinity, alignment: .center)
            .scaleEffect(configuration.scale(forDistance: offset - 2))
            .offset(x: configuration.horizontalOffset(availableWidth: 320))
            .frame(height: configuration.rowPitch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .frame(minHeight: configuration.itemExtent * 5)
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 8).onEnded { value in
        let steps = max(1, Int(abs(value.translation.height) / configuration.rowPitch))
        select(selectedIndex + (value.translation.height < 0 ? steps : -steps))
      }
    )
  }

  private var displayedRows: [Int] {
    guard !controls.isEmpty else { return [] }
    return (-2...2).map { projectedIndex(selectedIndex + $0) }
  }

  private func select(_ proposed: Int) {
    guard !controls.isEmpty else { return }
    selectedIndex = projectedIndex(proposed)
  }

  private func projectedIndex(_ proposed: Int) -> Int {
    guard configuration.looping else {
      return min(max(proposed, 0), controls.count - 1)
    }
    let remainder = proposed % controls.count
    return remainder >= 0 ? remainder : remainder + controls.count
  }
}
#endif
