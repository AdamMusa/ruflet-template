import RufletProtocol
import SwiftUI

/// Apple-native port of pinned `window_drag_area.dart`.
@MainActor
public struct WindowDragAreaControl: View {
  @ObservedObject public var control: RufletControl
  #if os(iOS)
    @State private var globalOrigin = CGPoint.zero
    @State private var dragging = false
  #endif

  public init(control: RufletControl) {
    self.control = control
  }

  public var body: some View {
    LayoutControl(control: control) {
      if let content = control.buildWidget("content") {
        dragArea(content)
      } else {
        ErrorControl("WindowDragArea.content must be provided and visible")
      }
    }
  }

  @ViewBuilder
  private func dragArea(_ content: AnyView) -> some View {
    #if os(macOS)
      content.overlay {
        RufletWindowDragPointerBridge(
          maximizable: control.boolean("maximizable", default: true),
          onDragStart: dragStarted,
          onDragEnd: dragEnded,
          onDoubleTap: doubleTapped)
      }
    #elseif os(iOS)
      content
        .background(
          GeometryReader { proxy in
            Color.clear
              .onAppear { globalOrigin = proxy.frame(in: .global).origin }
              .onChange(of: proxy.size) { _ in globalOrigin = proxy.frame(in: .global).origin }
          }
        )
        .gesture(
          DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
              guard !dragging else { return }
              dragging = true
              dragStarted(
                local: CGPoint(
                  x: value.startLocation.x - globalOrigin.x,
                  y: value.startLocation.y - globalOrigin.y),
                global: value.startLocation)
            }
            .onEnded { value in
              guard dragging else { return }
              dragging = false
              let predictionSeconds = 0.25
              let velocity = CGVector(
                dx: (value.predictedEndTranslation.width - value.translation.width)
                  / predictionSeconds,
                dy: (value.predictedEndTranslation.height - value.translation.height)
                  / predictionSeconds)
              dragEnded(
                local: CGPoint(
                  x: value.location.x - globalOrigin.x,
                  y: value.location.y - globalOrigin.y),
                global: value.location,
                velocity: velocity)
            })
    #endif
  }

  private func dragStarted(local: CGPoint, global: CGPoint) {
    control.triggerEvent(
      "drag_start",
      data: RufletDragStartDetails(
        localPosition: RufletEventPoint(local),
        globalPosition: RufletEventPoint(global),
        deviceKind: applePointerDeviceKind,
        timestamp: ProcessInfo.processInfo.systemUptime
      ).value)
  }

  private func dragEnded(local: CGPoint, global: CGPoint, velocity: CGVector) {
    control.triggerEvent(
      "drag_end",
      data: RufletDragEndDetails(
        localPosition: RufletEventPoint(local),
        globalPosition: RufletEventPoint(global),
        velocity: RufletEventPoint(x: Double(velocity.dx), y: Double(velocity.dy)),
        primaryVelocity: nil
      ).value)
  }

  private func doubleTapped(_ action: String) {
    control.triggerEvent("double_tap", data: .string(action))
  }

  private var applePointerDeviceKind: String {
    #if os(macOS)
      "mouse"
    #elseif os(iOS)
      "touch"
    #endif
  }
}
