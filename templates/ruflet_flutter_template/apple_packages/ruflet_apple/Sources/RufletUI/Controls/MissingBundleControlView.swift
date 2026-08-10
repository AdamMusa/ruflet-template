import RufletEngine
import SwiftUI

/// Stands in for a control whose module the app did not link.
///
/// Silence would be worse than a placeholder: a camera that renders nothing
/// looks like a broken layout, whereas this says which module to add. It only
/// appears in a debug build — a shipped app shows an empty frame rather than
/// scaffolding text.
struct MissingBundleControlView: View {
  let node: ControlNode
  let bundle: String

  var body: some View {
    #if DEBUG
      VStack(spacing: 6) {
        Image(systemName: "shippingbox")
          .font(.title2)
        Text("`\(node.type)` needs \(bundle)")
          .font(.caption)
          .multilineTextAlignment(.center)
        Text("Add it to your target's package dependencies.")
          .font(.caption2)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(12)
      .frame(maxWidth: .infinity)
      .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
      .onAppear {
        RufletLog.error("Control `\(node.type)` needs the \(bundle) module, which is not linked")
      }
    #else
      Color.clear
        .onAppear {
          RufletLog.error("Control `\(node.type)` needs the \(bundle) module, which is not linked")
        }
    #endif
  }
}
