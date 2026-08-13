import SwiftUI

struct RufletCornerShape: Shape {
    let radius: RufletBorderRadius

    func path(in rect: CGRect) -> Path {
        let tl = min(radius.topLeft, min(rect.width, rect.height) / 2)
        let tr = min(radius.topRight, min(rect.width, rect.height) / 2)
        let bl = min(radius.bottomLeft, min(rect.width, rect.height) / 2)
        let br = min(radius.bottomRight, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct RufletBorderOverlay: View {
    let border: RufletBorder
    let radius: RufletBorderRadius

    var body: some View {
        ZStack {
            side(border.top, edge: .top)
            side(border.bottom, edge: .bottom)
            side(border.left, edge: .leading)
            side(border.right, edge: .trailing)
        }
        .clipShape(RufletCornerShape(radius: radius))
    }

    @ViewBuilder
    private func side(_ side: RufletBorderSide?, edge: Edge) -> some View {
        if let side {
            Rectangle()
                .fill(side.color)
                .frame(
                    maxWidth: edge == .top || edge == .bottom ? .infinity : side.width,
                    maxHeight: edge == .leading || edge == .trailing ? .infinity : side.width
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge.alignment)
        }
    }
}

private extension Edge {
    var alignment: Alignment {
        switch self {
        case .top: .top
        case .bottom: .bottom
        case .leading: .leading
        case .trailing: .trailing
        }
    }
}
