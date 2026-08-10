import SwiftUI

/// Flows subviews onto as many lines as they need, for `wrap: true` stacks.
///
/// Uses SwiftUI's `Layout` where it exists. Below iOS 16 / macOS 13 there is no
/// way to measure siblings against a proposed width, so the content stays on
/// one scrollable line rather than silently clipping.
struct FlowLayout<Content: View>: View {
  let spacing: CGFloat
  let runSpacing: CGFloat
  @ViewBuilder let content: () -> Content

  var body: some View {
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
      FlowLayoutEngine(spacing: spacing, runSpacing: runSpacing) {
        content()
      }
    } else {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: spacing) { content() }
      }
    }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
private struct FlowLayoutEngine: Layout {
  let spacing: CGFloat
  let runSpacing: CGFloat

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Void
  ) -> CGSize {
    let width = proposal.width ?? .infinity
    let lines = layout(subviews: subviews, in: width)
    let height = lines.reduce(0) { $0 + $1.height } + runSpacing * CGFloat(max(lines.count - 1, 0))
    let widest = lines.map(\.width).max() ?? 0
    return CGSize(width: min(width, widest), height: height)
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Void
  ) {
    var y = bounds.minY
    for line in layout(subviews: subviews, in: bounds.width) {
      var x = bounds.minX
      for index in line.indices {
        let size = subviews[index].sizeThatFits(.unspecified)
        subviews[index].place(
          at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
        x += size.width + spacing
      }
      y += line.height + runSpacing
    }
  }

  private struct Line {
    var indices: [Int] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  private func layout(subviews: Subviews, in width: CGFloat) -> [Line] {
    var lines: [Line] = []
    var current = Line()

    for index in subviews.indices {
      let size = subviews[index].sizeThatFits(.unspecified)
      let advance = current.indices.isEmpty ? size.width : size.width + spacing
      if !current.indices.isEmpty, current.width + advance > width {
        lines.append(current)
        current = Line()
      }
      current.indices.append(index)
      current.width += current.indices.count == 1 ? size.width : advance
      current.height = max(current.height, size.height)
    }
    if !current.indices.isEmpty { lines.append(current) }
    return lines
  }
}
