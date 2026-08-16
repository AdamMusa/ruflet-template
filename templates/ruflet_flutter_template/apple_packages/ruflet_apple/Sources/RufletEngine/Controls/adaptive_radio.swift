import SwiftUI
@MainActor public struct AdaptiveRadioControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }
    public var body: some View { rufletUsesCupertinoPresentation(adaptive: control.adaptive, isIOS: rufletIsIOS) ? AnyView(CupertinoRadioControl(control: control)) : AnyView(RadioControl(control: control)) }
}
