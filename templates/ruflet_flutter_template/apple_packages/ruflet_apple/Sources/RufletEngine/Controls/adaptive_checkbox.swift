import SwiftUI
@MainActor public struct AdaptiveCheckboxControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }
    public var body: some View { control.adaptive == true ? AnyView(CupertinoCheckboxControl(control: control)) : AnyView(CheckboxControl(control: control)) }
}

var rufletIsIOS: Bool {
    #if os(iOS)
    true
    #else
    false
    #endif
}
