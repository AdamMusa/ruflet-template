import RufletEngine
import SwiftUI

struct RichAttributionControl: View {
  @ObservedObject var control: RufletControl
  @State private var popupPresented = false

  var body: some View {
    VStack(alignment: .trailing, spacing: 5) {
      if popupPresented {
        attributionPopup
          .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottomTrailing)))
      }
      HStack(spacing: 6) {
        permanentAttributions
        Button {
          withAnimation(.easeInOut(duration: 0.2)) { popupPresented.toggle() }
        } label: {
          Image(systemName: popupPresented ? "xmark.circle.fill" : "info.circle.fill")
            .imageScale(.medium)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(popupPresented ? "Close map attribution" : "Show map attribution")
      }
      .frame(height: control.number("permanent_height", default: 24) ?? 24)
    }
    .frame(
      maxWidth: .infinity, maxHeight: .infinity,
      alignment: RufletAttributionAlignment(control.string("alignment")).swiftUI)
    .padding(8)
    .onAppear { showInitialPopupIfNeeded() }
  }

  private var attributionPopup: some View {
    VStack(alignment: .leading, spacing: 7) {
      ForEach(control.children("attributions", visibleOnly: false), id: \.id) { source in
        attribution(source, compact: false)
      }
      if control.boolean("show_flutter_map_attribution", default: true) {
        Text("Ruflet Map · Apple MapKit").font(.caption2).foregroundStyle(.secondary)
      }
    }
    .padding(9)
    .background(rufletMapColor(control.string("popup_bgcolor"), default: Color.primary.opacity(0.08)))
    .clipShape(RoundedRectangle(cornerRadius: popupCornerRadius, style: .continuous))
    .shadow(radius: 3, y: 1)
  }

  private var permanentAttributions: some View {
    HStack(spacing: 6) {
      ForEach(control.children("attributions", visibleOnly: false).prefix(2), id: \.id) { source in
        attribution(source, compact: true)
      }
    }
  }

  @ViewBuilder
  private func attribution(_ source: RufletControl, compact: Bool) -> some View {
    let _ = markAsMapChild(source)
    if source.type == "TextSourceAttribution" {
      let style = parseTextStyle(source.value("text_style"))
      Text((source.boolean("prepend_copyright", default: true) ? "© " : "") + (source.string("text") ?? "Placeholder Text"))
        .font(.system(size: style?.size ?? (compact ? 10 : 12), weight: style?.weight ?? .regular))
        .foregroundStyle(style?.color ?? .primary)
        .lineLimit(compact ? 1 : nil)
        .contentShape(Rectangle())
        .onTapGesture { source.triggerEvent("click") }
    } else if source.type == "ImageSourceAttribution", let image = source.buildWidget("image") {
      image
        .frame(height: source.number("height", default: 24) ?? 24)
        .help(source.string("tooltip") ?? "")
        .contentShape(Rectangle())
        .onTapGesture { source.triggerEvent("click") }
    }
  }

  private var popupCornerRadius: Double {
    guard let radius = parseBorderRadius(control.value("popup_border_radius")) else { return 8 }
    return (radius.topLeft + radius.topRight + radius.bottomLeft + radius.bottomRight) / 4
  }

  private func markAsMapChild(_ source: RufletControl) -> Bool {
    source.notifyParent = true
    return true
  }

  private func showInitialPopupIfNeeded() {
    let duration = control.number("popup_initial_display_duration", default: 0) ?? 0
    guard duration > 0 else { return }
    popupPresented = true
    Task { @MainActor in
      try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000))
      withAnimation(.easeOut(duration: 0.2)) { popupPresented = false }
    }
  }
}
