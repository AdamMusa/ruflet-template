import SwiftUI

/// iOS 15/macOS 13-compatible intrinsic wrap layout. Alignment guides collect
/// each child's measured size and place it on the next run when necessary.
struct RufletFlowLayout: View {
    let axis: Axis
    let spacing: Double
    let runSpacing: Double
    let children: [AnyView]

    @State private var height: CGFloat = 0
    @State private var width: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            if axis == .horizontal {
                horizontalFlow(in: geometry.size.width)
            } else {
                verticalFlow(in: geometry.size.height)
            }
        }
        .frame(
            width: axis == .vertical ? width : nil,
            height: axis == .horizontal ? height : nil
        )
    }

    private func horizontalFlow(in availableWidth: CGFloat) -> some View {
        var x = CGFloat.zero
        var y = CGFloat.zero
        var lineHeight = CGFloat.zero
        return ZStack(alignment: .topLeading) {
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                child
                    .alignmentGuide(.leading) { dimensions in
                        if x > 0, x + dimensions.width > availableWidth {
                            x = 0
                            y += lineHeight + runSpacing
                            lineHeight = 0
                        }
                        let result = x
                        x += dimensions.width + spacing
                        lineHeight = max(lineHeight, dimensions.height)
                        return -result
                    }
                    .alignmentGuide(.top) { _ in -y }
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.onAppear { height = proxy.size.height }
            }
        }
        .onPreferenceChange(RufletFlowSizeKey.self) { height = $0.height }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: RufletFlowSizeKey.self, value: proxy.size)
            }
        }
    }

    private func verticalFlow(in availableHeight: CGFloat) -> some View {
        var x = CGFloat.zero
        var y = CGFloat.zero
        var columnWidth = CGFloat.zero
        return ZStack(alignment: .topLeading) {
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                child
                    .alignmentGuide(.leading) { _ in -x }
                    .alignmentGuide(.top) { dimensions in
                        if y > 0, y + dimensions.height > availableHeight {
                            y = 0
                            x += columnWidth + runSpacing
                            columnWidth = 0
                        }
                        let result = y
                        y += dimensions.height + spacing
                        columnWidth = max(columnWidth, dimensions.width)
                        return -result
                    }
            }
        }
        .onPreferenceChange(RufletFlowSizeKey.self) { width = $0.width }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: RufletFlowSizeKey.self, value: proxy.size)
            }
        }
    }
}

private struct RufletFlowSizeKey: PreferenceKey {
    static let defaultValue = CGSize.zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}
