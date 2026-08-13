import RufletEngine
import SwiftUI

struct SimpleAttributionControl: View {
  @ObservedObject var control: RufletControl

  var body: some View {
    HStack(spacing: 4) {
      control.buildTextOrWidget("text") ?? AnyView(Text("Placeholder Text"))
    }
    .font(.caption)
    .padding(.horizontal, 7)
    .padding(.vertical, 4)
    .background(rufletMapColor(control.string("bgcolor"), default: Color.primary.opacity(0.08)))
    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    .contentShape(Rectangle())
    .onTapGesture { control.triggerEvent("click") }
    .frame(
      maxWidth: .infinity, maxHeight: .infinity,
      alignment: attributionAlignment)
    .padding(8)
  }

  private var attributionAlignment: Alignment {
    guard let parsed = parseAlignment(control.value("alignment"), RufletAlignment(x: 1, y: 1)) else {
      return .bottomTrailing
    }
    return Alignment(
      horizontal: parsed.x < 0 ? .leading : parsed.x > 0 ? .trailing : .center,
      vertical: parsed.y < 0 ? .top : parsed.y > 0 ? .bottom : .center)
  }
}
