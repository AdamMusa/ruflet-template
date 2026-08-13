import SwiftUI

@MainActor
public struct CupertinoCheckboxControl: View {
    @ObservedObject public var control: RufletControl
    public init(control: RufletControl) { self.control = control }
    public var body: some View { CheckboxControl(control: control) }
}
