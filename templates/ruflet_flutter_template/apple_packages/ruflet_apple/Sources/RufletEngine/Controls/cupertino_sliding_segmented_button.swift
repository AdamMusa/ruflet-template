import RufletProtocol
import SwiftUI

/// Apple-native port of pinned Flet `CupertinoSlidingSegmentedButtonControl`.
@MainActor
public struct CupertinoSlidingSegmentedButtonControl: View {
  @ObservedObject public var control: RufletControl
  @StateObject private var coordinator: RufletIndexedSegmentCoordinator

  public init(control: RufletControl) {
    self.control = control
    _coordinator = StateObject(wrappedValue: RufletIndexedSegmentCoordinator(
      control: control, defaultIndex: 0, notify: true))
  }

  public var body: some View {
    LayoutControl(control: control) {
      if controls.count < 2 {
        ErrorControl("CupertinoSlidingSegmentedButton must have at minimum two visible controls")
      } else {
        HStack(spacing: 2) {
          ForEach(Array(controls.enumerated()), id: \.offset) { index, content in
            Button { coordinator.select(index) } label: {
              content
                .frame(
                  maxWidth: proportionalWidth ? nil : .infinity,
                  minHeight: 28)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
              coordinator.selectedIndex == index ? thumbColor : .clear,
              in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .shadow(
              color: coordinator.selectedIndex == index ? .black.opacity(0.18) : .clear,
              radius: 1.5,
              y: 1)
            .disabled(control.disabled)
            .accessibilityAddTraits(coordinator.selectedIndex == index ? .isSelected : [])
          }
        }
        .padding(parsePadding(control.dynamicValue("padding"))
          ?? EdgeInsets(top: 2, leading: 3, bottom: 2, trailing: 3))
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .animation(.easeInOut(duration: 0.18), value: coordinator.selectedIndex)
      }
    }
    .onAppear { coordinator.synchronizeFromControl() }
    .onChange(of: control.properties) { _ in coordinator.synchronizeFromControl() }
  }

  private var controls: [AnyView] { control.buildWidgets("controls") }
  private var proportionalWidth: Bool { control.boolean("proportional_width", default: false) }
  private var backgroundColor: Color {
    parseColor(control.string("bgcolor")) ?? .rufletCupertinoSegmentFill
  }
  private var thumbColor: Color {
    parseColor(control.string("thumb_color")) ?? .rufletCupertinoSegmentThumb
  }
}

private extension Color {
  static var rufletCupertinoSegmentFill: Color {
    #if os(iOS)
    Color(uiColor: .tertiarySystemFill)
    #else
    Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    #endif
  }

  static var rufletCupertinoSegmentThumb: Color {
    #if os(iOS)
    Color(uiColor: .secondarySystemBackground)
    #else
    Color(nsColor: .controlBackgroundColor)
    #endif
  }
}
