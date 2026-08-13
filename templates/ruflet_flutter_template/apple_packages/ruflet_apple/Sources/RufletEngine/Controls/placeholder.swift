import SwiftUI

@MainActor
public struct PlaceholderControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        LayoutControl(control: control) {
            ZStack {
                RufletPlaceholderShape()
                    .stroke(
                        parseColor(control.string("color")) ?? parseColor("bluegrey700")!,
                        lineWidth: control.number("stroke_width") ?? 2
                    )
                control.buildWidget("content")
            }
            .frame(
                width: control.number("fallback_width", default: 400).map { CGFloat($0) },
                height: control.number("fallback_height", default: 400).map { CGFloat($0) }
            )
        }
    }
}

private struct RufletPlaceholderShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}
