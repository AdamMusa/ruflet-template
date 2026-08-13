import SwiftUI

@MainActor
public struct TransparentPointerControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }

    public var body: some View {
        LayoutControl(control: control) {
            control.buildWidget("content")
                .allowsHitTesting(false)
        }
    }
}
