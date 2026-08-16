import Combine
import Foundation
import RufletProtocol

public let rufletComponentType = "C"
public let rufletComponentBodyProperty = "_b"

public enum RufletPatchOperation: Int, Sendable {
  case replace = 0
  case add = 1
  case remove = 2
  case move = 3
}

@MainActor
public protocol RufletBackendProtocol: AnyObject {
  var pageURI: URL? { get }
  var extensionRegistry: RufletExtensionRegistry { get }
  func index(_ control: RufletControl)
  func triggerControlEvent(_ control: RufletControl, name: String, data: RufletValue)
  func triggerControlEvent(controlID: Int, name: String, data: RufletValue)
  func updateControl(
    _ id: Int,
    properties: [String: RufletValue],
    client: Bool,
    server: Bool,
    notify: Bool)
  func resolveAssetSource(_ source: RufletValue) -> RufletAssetSource?
  func onWindowEvent(_ name: String, state: RufletWindowState)
  func registerScrollTarget(_ target: RufletScrollTarget, for key: String)
  func unregisterScrollTarget(_ target: RufletScrollTarget, for key: String)
  func scrollTarget(for key: String) -> RufletScrollTarget?
}

public extension RufletBackendProtocol {
  func registerScrollTarget(_ target: RufletScrollTarget, for key: String) {}
  func unregisterScrollTarget(_ target: RufletScrollTarget, for key: String) {}
  func scrollTarget(for key: String) -> RufletScrollTarget? { nil }
}

private indirect enum RufletMaterializedValue {
  case scalar(RufletValue)
  case control(RufletControl)
  case array([RufletMaterializedValue])
  case map([String: RufletMaterializedValue])
  case keyedMap([RufletMapKey: RufletMaterializedValue])

  @MainActor var wireValue: RufletValue {
    switch self {
    case .scalar(let value): return value
    case .control(let control): return control.valueMap
    case .array(let values): return .array(values.map(\.wireValue))
    case .map(let values): return .map(values.mapValues(\.wireValue))
    case .keyedMap(let values): return .keyedMap(values.mapValues(\.wireValue))
    }
  }

  @MainActor var propertyWireValue: RufletValue {
    switch self {
    case .scalar(let value): return value
    case .control(let control): return control.propertyMap
    case .array(let values): return .array(values.map(\.propertyWireValue))
    case .map(let values): return .map(values.mapValues(\.propertyWireValue))
    case .keyedMap(let values): return .keyedMap(values.mapValues(\.propertyWireValue))
    }
  }

  /// A shallow Equatable projection for SwiftUI `onChange` observers.
  /// Flet stores child `Control` references in its properties map; a child
  /// mutation therefore does not rebuild the parent's complete serialized
  /// subtree. Preserve that behavior by representing nested controls by
  /// identity here. Full recursive encoding remains available through
  /// `wireValue`, `valueMap`, and `propertyWireValue` at actual wire boundaries.
  @MainActor var observationValue: RufletValue {
    switch self {
    case .scalar(let value): return value
    case .control(let control):
      return .map(["_c": .string(control.type), "_i": .int(Int64(control.id))])
    case .array(let values): return .array(values.map(\.observationValue))
    case .map(let values): return .map(values.mapValues(\.observationValue))
    case .keyedMap(let values): return .keyedMap(values.mapValues(\.observationValue))
    }
  }
}

private struct RufletInvokeListener {
  let id: UUID
  let callback: RufletControl.InvokeMethodListener
}

private struct RufletUpdateListener {
  let id: UUID
  let callback: () -> Void
}

@MainActor
public final class RufletControl: ObservableObject, Identifiable {
  public typealias InvokeMethodListener = (String, RufletValue) async throws -> RufletValue

  public let id: Int
  public let type: String
  public private(set) var properties: [String: RufletValue]
  /// Monotonic change counter. `properties` holds this control's entire
  /// materialized subtree, so `onChange(of: properties)` costs a deep compare
  /// of every descendant on every render pass — quadratic on a large page.
  /// Observers that only need "did this control update" compare this instead.
  public private(set) var revision: Int = 0
  public var notifyParent = false
  public private(set) weak var parentControl: RufletControl?
  public unowned let backend: RufletBackendProtocol

  private var materializedProperties: [String: RufletMaterializedValue] = [:]
  private var invokeMethodListeners: [RufletInvokeListener] = []
  private var invokeListenerWaiters: [UUID: CheckedContinuation<Void, Never>] = [:]
  private var updateListeners: [RufletUpdateListener] = []

  public init(
    id: Int,
    type: String,
    properties: [String: RufletValue],
    backend: RufletBackendProtocol,
    parent: RufletControl? = nil
  ) {
    self.id = id
    self.type = type
    self.properties = [:]
    self.backend = backend
    self.parentControl = parent
    if type == rufletComponentType { notifyParent = true }

    // Flet indexes a parent before recursively materializing its descendants.
    // This guarantees nested controls can resolve the complete ancestry while
    // they are being constructed.
    backend.index(self)
    materializedProperties = properties.mapValues { materialize($0, parent: self) }
    synchronizeWireProperties()
  }

  public convenience init(
    value: RufletValue,
    backend: RufletBackendProtocol,
    parent: RufletControl? = nil
  ) throws {
    guard let map = value.map else { throw RufletControlError.invalidControl }
    guard let type = map["_c"]?.text else { throw RufletControlError.missingType }
    guard let id = map["_i"]?.integer else { throw RufletControlError.missingID }
    var properties = map
    properties.removeValue(forKey: "_c")
    properties.removeValue(forKey: "_i")
    self.init(id: id, type: type, properties: properties, backend: backend, parent: parent)
  }

  public var parent: RufletControl? {
    var candidate = parentControl
    while candidate?.type == rufletComponentType { candidate = candidate?.parentControl }
    return candidate
  }

  public var disabled: Bool { boolean("disabled") == true || (parent?.disabled ?? false) }
  public var adaptive: Bool? { boolean("adaptive") ?? parent?.adaptive }
  public var visible: Bool { boolean("visible", default: true) }
  public var internals: [String: RufletValue]? { value("_internals")?.map }

  public func value(_ name: String) -> RufletValue? {
    guard let materialized = materializedProperties[name] else { return nil }
    if case .control(let component) = materialized, component.type == rufletComponentType {
      return component.value(rufletComponentBodyProperty)
    }
    return materialized.wireValue
  }

  public func string(_ name: String, default defaultValue: String? = nil) -> String? {
    guard let value = primitiveValue(name) else { return defaultValue }
    switch value {
    case .string(let text): return text
    case .bool(let flag): return String(flag)
    case .int(let integer): return String(integer)
    case .double(let number): return String(number)
    default: return defaultValue
    }
  }

  public func boolean(_ name: String, default defaultValue: Bool? = nil) -> Bool? {
    primitiveValue(name)?.bool ?? defaultValue
  }

  public func boolean(_ name: String, default defaultValue: Bool) -> Bool {
    primitiveValue(name)?.bool ?? defaultValue
  }

  public func integer(_ name: String, default defaultValue: Int? = nil) -> Int? {
    primitiveValue(name)?.integer ?? defaultValue
  }

  public func number(_ name: String, default defaultValue: Double? = nil) -> Double? {
    primitiveValue(name)?.number ?? defaultValue
  }

  /// Resolves the literal primitive default extracted from the exact pinned
  /// Flet renderer when the wire omits or nulls the property. Raw `value(_:)`
  /// deliberately stays wire-only for patching and property-presence checks.
  private func primitiveValue(_ name: String) -> RufletValue? {
    if let explicit = value(name), explicit != .null { return explicit }
    return RufletControlDefaults.value(for: type, property: name)
  }

  public func child(_ name: String, visibleOnly: Bool = true) -> RufletControl? {
    guard case .control(let control) = materializedProperties[name] else { return nil }
    return visibleOnly && !control.visible ? nil : control
  }

  public func children(_ name: String, visibleOnly: Bool = true) -> [RufletControl] {
    let controls: [RufletControl]
    switch materializedProperties[name] {
    case .control(let control): controls = [control]
    case .array(let values):
      controls = values.compactMap {
        guard case .control(let control) = $0 else { return nil }
        return control
      }
    default: controls = []
    }
    return controls.map { $0.unwrapComponent() }.filter { !visibleOnly || $0.visible }
  }

  public func unwrapComponent() -> RufletControl {
    var result = self
    while result.type == rufletComponentType,
          case .control(let body) = result.materializedProperties[rufletComponentBodyProperty] {
      result = body
    }
    return result
  }

  public func hasEventHandler(_ name: String) -> Bool {
    boolean(name.hasPrefix("on_") ? name : "on_\(name)", default: false)
  }

  public func triggerEvent(_ name: String, data: RufletValue = .null) {
    backend.triggerControlEvent(self, name: name, data: data)
  }

  public func triggerEventWithoutSubscribers(_ name: String, data: RufletValue = .null) {
    backend.triggerControlEvent(controlID: id, name: name, data: data)
  }

  public func updateProperties(
    _ values: [String: RufletValue],
    client: Bool = true,
    server: Bool = true,
    notify: Bool = false
  ) {
    backend.updateControl(id, properties: values, client: client, server: server, notify: notify)
  }

  @discardableResult
  public func update(_ values: [String: RufletValue], notify: Bool = false) -> Bool {
    var changedPaths: [String] = []
    var changedControls: [RufletControl] = []
    var visibleOwners: [RufletControl] = []
    mergeProperties(
      values,
      prefix: "",
      changedPaths: &changedPaths,
      changedControls: &changedControls,
      visibleOwners: &visibleOwners)
    finishMutation(
      changedPaths: changedPaths,
      changedControls: changedControls,
      visibleOwners: visibleOwners,
      notify: notify)
    return !changedPaths.isEmpty
  }

  /// Applies operations directly to their indexed target, matching Flet's
  /// `Control.applyPatch`. Only values on the addressed path are copied by
  /// Swift's value semantics; the complete control tree is never serialized
  /// to a wire snapshot or recursively reconciled.
  public func applyPatch(_ patch: [RufletValue], notify: Bool = true) throws {
    guard patch.count >= 2 else { throw RufletPatchError.malformedPatch }
    var paths: [Int: [RufletValue]] = [:]
    try buildPatchPaths(patch[0], path: [], result: &paths)

    for encodedOperation in patch.dropFirst() {
      guard let operation = encodedOperation.array,
            let opcode = operation.first?.integer,
            let operationType = RufletPatchOperation(rawValue: opcode)
      else { throw RufletPatchError.malformedOperation }

      switch operationType {
      case .replace:
        guard operation.count >= 4,
              let targetID = operation[1].integer,
              let path = paths[targetID]
        else { throw RufletPatchError.malformedOperation }
        let owner = try mutatePatchTarget(path: path) { container, owner in
          try patchReplace(&container, key: operation[2], value: operation[3], owner: owner)
          return owner
        }
        if notify { owner.notify() }
        if operation[2].text == "visible" { owner.parentControl?.notify() }

      case .add:
        guard operation.count >= 4,
              let targetID = operation[1].integer,
              let path = paths[targetID]
        else { throw RufletPatchError.malformedOperation }
        let owner = try mutatePatchTarget(path: path) { container, owner in
          try patchAdd(&container, key: operation[2], value: operation[3], owner: owner)
          return owner
        }
        if notify { owner.notify() }

      case .remove:
        guard operation.count >= 3,
              let targetID = operation[1].integer,
              let path = paths[targetID]
        else { throw RufletPatchError.malformedOperation }
        let owner = try mutatePatchTarget(path: path) { container, owner in
          _ = try patchRemove(&container, key: operation[2])
          return owner
        }
        if notify { owner.notify() }

      case .move:
        guard operation.count >= 5,
              let sourceID = operation[1].integer,
              let destinationID = operation[3].integer,
              let sourcePath = paths[sourceID],
              let destinationPath = paths[destinationID]
        else { throw RufletPatchError.malformedOperation }
        let sourceKind = try patchContainerKind(path: sourcePath)
        let destinationKind = try patchContainerKind(path: destinationPath)
        guard sourceKind == destinationKind else { throw RufletPatchError.invalidPath }
        var sourceOwner: RufletControl?
        let moved = try mutatePatchTarget(path: sourcePath) { container, owner in
          sourceOwner = owner
          if let value = try patchRemove(&container, key: operation[2]) { return value }
          // Dart's `Map.remove` returns null when the key is absent, and MOVE
          // assigns that null to the destination map. Lists still reject an
          // out-of-range source index.
          if sourceKind == .map { return .scalar(.null) }
          throw RufletPatchError.invalidPath
        }
        let destinationOwner = try mutatePatchTarget(path: destinationPath) { container, owner in
          try patchInsertMaterialized(&container, key: operation[4], value: moved)
          return owner
        }
        if notify {
          if let sourceOwner, sourceOwner !== destinationOwner { sourceOwner.notify() }
          destinationOwner.notify()
        }
      }
    }
  }

  @discardableResult
  public func addListener(_ listener: @escaping () -> Void) -> UUID {
    let id = UUID()
    updateListeners.append(RufletUpdateListener(id: id, callback: listener))
    return id
  }

  public func removeListener(_ token: UUID) {
    updateListeners.removeAll { $0.id == token }
  }

  @discardableResult
  public func addInvokeMethodListener(_ listener: @escaping InvokeMethodListener) -> UUID {
    let id = UUID()
    invokeMethodListeners.append(RufletInvokeListener(id: id, callback: listener))
    let waiters = invokeListenerWaiters.values
    invokeListenerWaiters.removeAll()
    waiters.forEach { $0.resume() }
    return id
  }

  public func removeInvokeMethodListener(_ token: UUID) {
    invokeMethodListeners.removeAll { $0.id == token }
  }

  public func invokeMethod(_ name: String, arguments: RufletValue) async throws -> RufletValue {
    if invokeMethodListeners.isEmpty {
      try await waitForInvokeMethodListener()
    }
    try Task.checkCancellation()
    guard !invokeMethodListeners.isEmpty else { throw RufletControlError.noMethodListener }
    let listeners = invokeMethodListeners
    var results: [RufletValue] = []
    for listener in listeners {
      try Task.checkCancellation()
      results.append(try await listener.callback(name, arguments))
    }
    return results.count == 1 ? results[0] : .array(results)
  }

  public var valueMap: RufletValue {
    var result = materializedProperties.mapValues(\.wireValue)
    result["_c"] = .string(type)
    result["_i"] = .int(Int64(id))
    return .map(result)
  }

  /// Matches pinned `Control.toMap()`: properties only, recursively stripping
  /// control identity metadata. This is used by registration payloads such as
  /// Window configuration; `valueMap` remains the full control-tree encoding.
  public var propertyMap: RufletValue {
    .map(materializedProperties.compactMapValues { value in
      let wireValue = value.propertyWireValue
      if wireValue.isNull { return Optional<RufletValue>.none }
      return Optional.some(wireValue)
    })
  }

  private func materialize(_ value: RufletValue, parent: RufletControl) -> RufletMaterializedValue {
    switch value {
    case .map(let values):
      if values["_c"] != nil,
         let control = try? RufletControl(value: value, backend: backend, parent: parent) {
        return .control(control)
      }
      return .map(values.mapValues { materialize($0, parent: parent) })
    case .keyedMap(let values):
      let type = values[.string("_c")]
      let id = values[.string("_i")]
      if type != nil, id != nil {
        var stringMap: [String: RufletValue] = [:]
        for (key, value) in values {
          guard case .string(let key) = key else { return .keyedMap(values.mapValues { materialize($0, parent: parent) }) }
          stringMap[key] = value
        }
        if let control = try? RufletControl(value: .map(stringMap), backend: backend, parent: parent) {
          return .control(control)
        }
      }
      return .keyedMap(values.mapValues { materialize($0, parent: parent) })
    case .array(let values):
      return .array(values.map { materialize($0, parent: parent) })
    default:
      return .scalar(value)
    }
  }

  private func mergeProperties(
    _ incoming: [String: RufletValue],
    prefix: String,
    changedPaths: inout [String],
    changedControls: inout [RufletControl],
    visibleOwners: inout [RufletControl]
  ) {
    for (key, value) in incoming where key != "_i" && key != "_c" {
      let path = prefix.isEmpty ? key : "\(prefix).\(key)"
      if var existing = materializedProperties[key] {
        mergeValue(
          &existing,
          incoming: value,
          owner: self,
          path: path,
          propertyName: key,
          changedPaths: &changedPaths,
          changedControls: &changedControls,
          visibleOwners: &visibleOwners)
        materializedProperties[key] = existing
      } else {
        materializedProperties[key] = materialize(value, parent: self)
        recordChange(
          path: path,
          propertyName: key,
          owner: self,
          changedPaths: &changedPaths,
          changedControls: &changedControls,
          visibleOwners: &visibleOwners)
      }
    }
    synchronizeWireProperties()
  }

  private func mergeValue(
    _ destination: inout RufletMaterializedValue,
    incoming: RufletValue,
    owner: RufletControl,
    path: String,
    propertyName: String,
    changedPaths: inout [String],
    changedControls: inout [RufletControl],
    visibleOwners: inout [RufletControl]
  ) {
    switch (destination, incoming) {
    case (.control(let control), .map(let incomingMap))
      where incomingMap["_i"]?.integer == control.id:
      control.mergeProperties(
        incomingMap,
        prefix: path,
        changedPaths: &changedPaths,
        changedControls: &changedControls,
        visibleOwners: &visibleOwners)

    case (.map(var destinationMap), .map(let incomingMap)):
      for (key, value) in incomingMap {
        let childPath = "\(path).\(key)"
        if var existing = destinationMap[key] {
          mergeValue(
            &existing,
            incoming: value,
            owner: owner,
            path: childPath,
            propertyName: key,
            changedPaths: &changedPaths,
            changedControls: &changedControls,
            visibleOwners: &visibleOwners)
          destinationMap[key] = existing
        } else {
          destinationMap[key] = materialize(value, parent: owner)
          recordChange(
            path: childPath,
            propertyName: key,
            owner: owner,
            changedPaths: &changedPaths,
            changedControls: &changedControls,
            visibleOwners: &visibleOwners)
        }
      }
      destination = .map(destinationMap)

    case (.keyedMap(var destinationMap), _):
      guard let incomingMap = incoming.keyedMap else {
        replaceValue(
          &destination,
          incoming: incoming,
          owner: owner,
          path: path,
          propertyName: propertyName,
          changedPaths: &changedPaths,
          changedControls: &changedControls,
          visibleOwners: &visibleOwners)
        return
      }
      for (key, value) in incomingMap {
        let childPath = "\(path).\(key.pathDescription)"
        if var existing = destinationMap[key] {
          mergeValue(
            &existing,
            incoming: value,
            owner: owner,
            path: childPath,
            propertyName: key.pathDescription,
            changedPaths: &changedPaths,
            changedControls: &changedControls,
            visibleOwners: &visibleOwners)
          destinationMap[key] = existing
        } else {
          destinationMap[key] = materialize(value, parent: owner)
          recordChange(
            path: childPath,
            propertyName: key.pathDescription,
            owner: owner,
            changedPaths: &changedPaths,
            changedControls: &changedControls,
            visibleOwners: &visibleOwners)
        }
      }
      destination = .keyedMap(destinationMap)

    default:
      replaceValue(
        &destination,
        incoming: incoming,
        owner: owner,
        path: path,
        propertyName: propertyName,
        changedPaths: &changedPaths,
        changedControls: &changedControls,
        visibleOwners: &visibleOwners)
    }
  }

  private func replaceValue(
    _ destination: inout RufletMaterializedValue,
    incoming: RufletValue,
    owner: RufletControl,
    path: String,
    propertyName: String,
    changedPaths: inout [String],
    changedControls: inout [RufletControl],
    visibleOwners: inout [RufletControl]
  ) {
    guard destination.wireValue != incoming else { return }
    destination = materialize(incoming, parent: owner)
    recordChange(
      path: path,
      propertyName: propertyName,
      owner: owner,
      changedPaths: &changedPaths,
      changedControls: &changedControls,
      visibleOwners: &visibleOwners)
  }

  private func recordChange(
    path: String,
    propertyName: String,
    owner: RufletControl,
    changedPaths: inout [String],
    changedControls: inout [RufletControl],
    visibleOwners: inout [RufletControl]
  ) {
    changedPaths.append(path)
    if !changedControls.contains(where: { $0 === owner }) { changedControls.append(owner) }
    // Pinned Flet tests the complete changed path against the literal
    // `_notifyParentProperties` list. A direct `visible` update invalidates
    // the parent; `content.visible` in a root-level deep merge does not.
    if path == "visible", !visibleOwners.contains(where: { $0 === owner }) {
      visibleOwners.append(owner)
    }
  }

  private func finishMutation(
    changedPaths: [String],
    changedControls: [RufletControl],
    visibleOwners: [RufletControl],
    notify: Bool
  ) {
    guard !changedPaths.isEmpty else { return }
    if notify { changedControls.forEach { $0.notify() } }
    for owner in visibleOwners {
      owner.parentControl?.notify()
    }
  }

  private func notify() {
    if notifyParent, let parentControl {
      parentControl.notify()
      return
    }
    revision &+= 1
    objectWillChange.send()
    let listeners = updateListeners
    listeners.forEach { $0.callback() }
  }

  private func synchronizeWireProperties() {
    properties = materializedProperties.mapValues(\.observationValue)
  }

  private func waitForInvokeMethodListener() async throws {
    let id = UUID()
    try Task.checkCancellation()
    await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        if invokeMethodListeners.isEmpty {
          invokeListenerWaiters[id] = continuation
        } else {
          continuation.resume()
        }
      }
    } onCancel: {
      Task { @MainActor [weak self] in self?.resumeInvokeWaiter(id) }
    }
    try Task.checkCancellation()
  }

  private func resumeInvokeWaiter(_ id: UUID) {
    invokeListenerWaiters.removeValue(forKey: id)?.resume()
  }

  private enum PatchContainerKind: Equatable {
    case array
    case map
  }

  private func mutatePatchTarget<Result>(
    path: [RufletValue],
    mutation: (inout RufletMaterializedValue, RufletControl) throws -> Result
  ) throws -> Result {
    var root = RufletMaterializedValue.map(materializedProperties)
    let result = try mutatePatchTargetValue(
      &root, path: ArraySlice(path), owner: self, mutation: mutation)
    guard case .map(let updated) = root else { throw RufletPatchError.invalidPath }
    materializedProperties = updated
    synchronizeWireProperties()
    return result
  }

  private func mutatePatchTargetValue<Result>(
    _ value: inout RufletMaterializedValue,
    path: ArraySlice<RufletValue>,
    owner: RufletControl,
    mutation: (inout RufletMaterializedValue, RufletControl) throws -> Result
  ) throws -> Result {
    if case .control(let control) = value {
      var properties = RufletMaterializedValue.map(control.materializedProperties)
      let result = try control.mutatePatchTargetValue(
        &properties, path: path, owner: control, mutation: mutation)
      guard case .map(let updated) = properties else { throw RufletPatchError.invalidPath }
      control.materializedProperties = updated
      control.synchronizeWireProperties()
      return result
    }

    guard let component = path.first else { return try mutation(&value, owner) }
    let remaining = path.dropFirst()
    if let name = component.text {
      if case .map(var values) = value, var child = values[name] {
        let result = try mutatePatchTargetValue(
          &child, path: remaining, owner: owner, mutation: mutation)
        values[name] = child
        value = .map(values)
        return result
      }
      if case .keyedMap(var values) = value, var child = values[.string(name)] {
        let result = try mutatePatchTargetValue(
          &child, path: remaining, owner: owner, mutation: mutation)
        values[.string(name)] = child
        value = .keyedMap(values)
        return result
      }
    }
    if let index = component.integer {
      if case .array(var values) = value, values.indices.contains(index) {
        var child = values[index]
        let result = try mutatePatchTargetValue(
          &child, path: remaining, owner: owner, mutation: mutation)
        values[index] = child
        value = .array(values)
        return result
      }
      if case .keyedMap(var values) = value, var child = values[.int(Int64(index))] {
        let result = try mutatePatchTargetValue(
          &child, path: remaining, owner: owner, mutation: mutation)
        values[.int(Int64(index))] = child
        value = .keyedMap(values)
        return result
      }
    }
    throw RufletPatchError.invalidPath
  }

  private func patchContainerKind(path: [RufletValue]) throws -> PatchContainerKind {
    try mutatePatchTarget(path: path) { container, _ in
      switch container {
      case .array: return .array
      case .map, .keyedMap: return .map
      default: throw RufletPatchError.invalidPath
      }
    }
  }

  private func patchReplace(
    _ container: inout RufletMaterializedValue,
    key: RufletValue,
    value: RufletValue,
    owner: RufletControl
  ) throws {
    let transformed = materialize(value, parent: owner)
    if case .array(var values) = container, let index = key.integer,
       values.indices.contains(index) {
      values[index] = transformed
      container = .array(values)
      return
    }
    try patchAssignMap(&container, key: key, value: transformed)
  }

  private func patchAdd(
    _ container: inout RufletMaterializedValue,
    key: RufletValue,
    value: RufletValue,
    owner: RufletControl
  ) throws {
    let transformed = materialize(value, parent: owner)
    try patchInsertMaterialized(&container, key: key, value: transformed)
  }

  private func patchInsertMaterialized(
    _ container: inout RufletMaterializedValue,
    key: RufletValue,
    value: RufletMaterializedValue
  ) throws {
    if case .array(var values) = container, let index = key.integer,
       index >= 0, index <= values.count {
      values.insert(value, at: index)
      container = .array(values)
      return
    }
    try patchAssignMap(&container, key: key, value: value)
  }

  private func patchAssignMap(
    _ container: inout RufletMaterializedValue,
    key: RufletValue,
    value: RufletMaterializedValue
  ) throws {
    if case .map(var values) = container, let name = key.text {
      values[name] = value
      container = .map(values)
      return
    }
    if case .keyedMap(var values) = container, let mapKey = RufletMapKey(value: key) {
      values[mapKey] = value
      container = .keyedMap(values)
      return
    }
    throw RufletPatchError.invalidPath
  }

  private func patchRemove(
    _ container: inout RufletMaterializedValue,
    key: RufletValue
  ) throws -> RufletMaterializedValue? {
    if case .array(var values) = container, let index = key.integer,
       values.indices.contains(index) {
      let removed = values.remove(at: index)
      container = .array(values)
      return removed
    }
    if case .map(var values) = container, let name = key.text {
      let removed = values.removeValue(forKey: name)
      container = .map(values)
      return removed
    }
    if case .keyedMap(var values) = container, let mapKey = RufletMapKey(value: key) {
      let removed = values.removeValue(forKey: mapKey)
      container = .keyedMap(values)
      return removed
    }
    throw RufletPatchError.invalidPath
  }

  private func buildPatchPaths(
    _ nodeValue: RufletValue,
    path: [RufletValue],
    result: inout [Int: [RufletValue]]
  ) throws {
    guard let node = nodeValue.array,
          let id = node.first?.integer
    else { throw RufletPatchError.malformedTreeIndex }
    result[id] = path
    guard node.count > 1, let children = node[1].keyedMap else { return }
    for (component, child) in children {
      try buildPatchPaths(child, path: path + [component.value], result: &result)
    }
  }

}

extension RufletControl: @preconcurrency Equatable {
  /// Pinned Flet `Control.operator ==` compares identity, wire type, and the
  /// complete recursively materialized property map. The backend and parent
  /// are deliberately not part of value equality.
  public static func == (lhs: RufletControl, rhs: RufletControl) -> Bool {
    lhs === rhs
      || (lhs.id == rhs.id
        && lhs.type == rhs.type
        && lhs.valueMap == rhs.valueMap)
  }
}

private extension RufletMapKey {
  init?(value: RufletValue) {
    if let text = value.text {
      self = .string(text)
    } else if let integer = value.integer {
      self = .int(Int64(integer))
    } else {
      return nil
    }
  }

  var pathDescription: String {
    switch self {
    case .string(let value): return value
    case .int(let value): return String(value)
    }
  }
}

public enum RufletControlError: Error, Equatable {
  case invalidControl
  case missingType
  case missingID
  case noMethodListener
}

public enum RufletPatchError: Error, Equatable {
  case malformedPatch
  case malformedTreeIndex
  case malformedOperation
  case invalidPath
}
