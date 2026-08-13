import SwiftUI

@MainActor
struct ControlInheritedNotifier<Content: View>: View {
    @ObservedObject var control: RufletControl
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
    }
}

@MainActor
extension RufletControl {
    var skipsInheritedNotifier: Bool {
        internals?["skip_inherited_notifier"]?.bool == true
    }
}
