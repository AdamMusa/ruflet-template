import RufletProtocol
import SwiftUI

@MainActor
final class RufletDragSession {
    static let shared = RufletDragSession()

    private struct TargetKey: Hashable {
        let backend: ObjectIdentifier
        let controlID: Int
    }

    private struct Target {
        let control: RufletControl
        let group: String
        var frame: CGRect
    }

    private struct Source {
        let control: RufletControl
        let group: String
    }

    private var targets: [TargetKey: Target] = [:]
    private var source: Source?
    private var currentTarget: TargetKey?
    private var currentTargetAccepts = false

    func register(target control: RufletControl, group: String, frame: CGRect) {
        targets[key(for: control)] = Target(control: control, group: group, frame: frame)
    }

    func unregister(target control: RufletControl) {
        targets.removeValue(forKey: key(for: control))
    }

    func begin(source control: RufletControl, group: String) {
        self.source = Source(control: control, group: group)
        currentTarget = nil
        currentTargetAccepts = false
        control.triggerEvent("drag_start")
    }

    func move(to globalLocation: CGPoint) {
        guard let source else { return }
        let candidate = targets.first { key, target in
            key.backend == ObjectIdentifier(source.control.backend) && target.frame.contains(globalLocation)
        }

        if candidate?.key != currentTarget {
            if let currentTarget, let previous = targets[currentTarget] {
                previous.control.triggerEvent("leave", data: ["src_id": .int(Int64(source.control.id))])
            }
            currentTarget = candidate?.key
            currentTargetAccepts = candidate?.value.group == source.group
            if let target = candidate?.value {
                target.control.triggerEvent("will_accept", data: [
                    "accept": .bool(currentTargetAccepts),
                    "src_id": .int(Int64(source.control.id)),
                ])
            }
        }

        if let currentTarget, currentTargetAccepts, let target = targets[currentTarget] {
            target.control.triggerEvent("move", data: dragTargetEvent(sourceID: source.control.id, location: globalLocation))
        }
    }

    @discardableResult
    func end(at globalLocation: CGPoint) -> Bool {
        move(to: globalLocation)
        guard let source else { return false }
        let accepted: Bool
        if let currentTarget, currentTargetAccepts, let target = targets[currentTarget] {
            target.control.triggerEvent("accept", data: dragTargetEvent(sourceID: source.control.id, location: globalLocation))
            source.control.triggerEvent("drag_complete", data: .string(source.group))
            accepted = true
        } else {
            if let currentTarget, let target = targets[currentTarget] {
                target.control.triggerEvent("leave", data: ["src_id": .int(Int64(source.control.id))])
            }
            accepted = false
        }
        self.source = nil
        currentTarget = nil
        currentTargetAccepts = false
        return accepted
    }

    private func key(for control: RufletControl) -> TargetKey {
        TargetKey(backend: ObjectIdentifier(control.backend), controlID: control.id)
    }

    private func dragTargetEvent(sourceID: Int, location: CGPoint) -> RufletValue {
        [
            "src_id": .int(Int64(sourceID)),
            "x": .double(location.x),
            "y": .double(location.y),
        ]
    }
}

private struct RufletDragTargetFrameKey: PreferenceKey {
    static let defaultValue = CGRect.zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

@MainActor
struct RufletDragTargetRegistration: ViewModifier {
    @ObservedObject var control: RufletControl
    let group: String

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: RufletDragTargetFrameKey.self,
                        value: proxy.frame(in: .global)
                    )
                }
            }
            .onPreferenceChange(RufletDragTargetFrameKey.self) { frame in
                RufletDragSession.shared.register(target: control, group: group, frame: frame)
            }
            .onDisappear { RufletDragSession.shared.unregister(target: control) }
    }
}
