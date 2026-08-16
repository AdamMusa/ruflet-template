import SwiftUI
@MainActor public struct AdaptiveSliderControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }
    public var body: some View { control.adaptive == true ? AnyView(CupertinoSliderControl(control: control)) : AnyView(SliderControl(control: control)) }
}
