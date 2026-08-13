import SwiftUI

private struct ReorderableItemIndexKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

extension EnvironmentValues {
    var reorderableItemIndex: Int? {
        get { self[ReorderableItemIndexKey.self] }
        set { self[ReorderableItemIndexKey.self] = newValue }
    }
}

struct ReorderableItemScope<Content: View>: View {
    let index: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        content().environment(\.reorderableItemIndex, index)
    }
}
