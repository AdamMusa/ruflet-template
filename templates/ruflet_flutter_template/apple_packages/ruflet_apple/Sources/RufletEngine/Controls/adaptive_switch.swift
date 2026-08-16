import SwiftUI
@MainActor public struct AdaptiveSwitchControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }
    public var body: some View { rufletUsesCupertinoPresentation(adaptive: control.adaptive, isIOS: rufletIsIOS) ? AnyView(CupertinoSwitchControl(control: control)) : AnyView(SwitchControl(control: control)) }
}
