import SwiftUI
@MainActor public struct AdaptiveSliderControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }
    public var body: some View { rufletUsesCupertinoPresentation(adaptive: control.adaptive, isIOS: rufletIsIOS) ? AnyView(CupertinoSliderControl(control: control)) : AnyView(SliderControl(control: control)) }
}
