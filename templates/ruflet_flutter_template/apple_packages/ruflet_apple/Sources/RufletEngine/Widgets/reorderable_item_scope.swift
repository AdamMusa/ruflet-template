import SwiftUI
import Foundation

private struct ReorderableItemIndexKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

extension EnvironmentValues {
    var reorderableItemIndex: Int? {
        get { self[ReorderableItemIndexKey.self] }
        set { self[ReorderableItemIndexKey.self] = newValue }
    }

    var rufletReorderItemActions: RufletReorderItemActions? {
        get { self[RufletReorderItemActionsKey.self] }
        set { self[RufletReorderItemActionsKey.self] = newValue }
    }
}

struct ReorderableItemScope<Content: View>: View {
    let index: Int
    let actions: RufletReorderItemActions
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .environment(\.reorderableItemIndex, index)
            .environment(\.rufletReorderItemActions, actions)
    }
}

struct RufletReorderItemActions {
    let beginDragging: (Int) -> NSItemProvider
}

private struct RufletReorderItemActionsKey: EnvironmentKey {
    static let defaultValue: RufletReorderItemActions? = nil
}
