import RufletProtocol
import SwiftUI

/// Resolves a Ruflet control through the registered renderer extensions.
/// Unknown controls are programmer/protocol errors; the native renderer does
/// not substitute a placeholder or a different rendering engine.
@MainActor
public struct ControlWidget: View {
    @ObservedObject private var control: RufletControl
    @EnvironmentObject private var registry: RufletExtensionRegistry

    public init(control: RufletControl) {
        self.control = control
    }

    public var body: some View {
        resolvedView
            .id(controlKey)
    }

    private var resolvedView: AnyView {
        guard let view = registry.view(for: control) else {
            preconditionFailure("Unknown Ruflet control: \(control.type)")
        }
        return view
    }

    private var controlKey: AnyHashable {
        parseKey(control.value("key")).map(AnyHashable.init) ?? AnyHashable(control.id)
    }
}

@MainActor
extension RufletControl {
    public func buildWidgets(
        _ propertyName: String,
        visibleOnly: Bool = true,
        notifyParent: Bool = false
    ) -> [AnyView] {
        children(propertyName, visibleOnly: visibleOnly).map { child in
            child.notifyParent = notifyParent
            return AnyView(ControlWidget(control: child))
        }
    }

    public func buildWidget(
        _ propertyName: String,
        visibleOnly: Bool = true,
        notifyParent: Bool = false
    ) -> AnyView? {
        guard let child = child(propertyName, visibleOnly: visibleOnly) else { return nil }
        child.notifyParent = notifyParent
        return AnyView(ControlWidget(control: child))
    }

    public func buildTextOrWidget(
        _ propertyName: String,
        visibleOnly: Bool = true,
        notifyParent: Bool = false,
        required: Bool = false
    ) -> AnyView? {
        if let child = buildWidget(
            propertyName,
            visibleOnly: visibleOnly,
            notifyParent: notifyParent
        ) {
            return child
        }
        if let text = string(propertyName) {
            return AnyView(Text(text))
        }
        if required {
            return AnyView(ErrorControl("Error displaying \(type)", description: "\(propertyName) must be specified"))
        }
        return nil
    }
}

@MainActor
struct RufletSystemIcon: View {
    let code: Int
    @EnvironmentObject private var registry: RufletExtensionRegistry

    var body: some View {
        Image(systemName: resolvedName)
    }

    private var resolvedName: String {
        guard let name = registry.systemIconName(for: code) else {
            preconditionFailure("Unknown Ruflet icon code: \(code)")
        }
        return name
    }
}

@MainActor
extension RufletControl {
    public func buildIconOrWidget(
        _ propertyName: String,
        visibleOnly: Bool = true,
        notifyParent: Bool = false,
        color: Color? = nil
    ) -> AnyView? {
        if let child = buildWidget(
            propertyName,
            visibleOnly: visibleOnly,
            notifyParent: notifyParent
        ) {
            return child
        }
        guard let code = integer(propertyName) else { return nil }
        return AnyView(RufletSystemIcon(code: code).foregroundStyle(color ?? .primary))
    }
}
