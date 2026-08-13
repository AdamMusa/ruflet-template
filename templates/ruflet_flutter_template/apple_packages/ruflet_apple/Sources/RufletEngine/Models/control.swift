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
    guard let value = value(name) else { return defaultValue }
    switch value {
    case .string(let text): return text
    case .bool(let flag): return String(flag)
    case .int(let integer): return String(integer)
    case .double(let number): return String(number)
    default: return defaultValue
    }
  }

  public func boolean(_ name: String, default defaultValue: Bool? = nil) -> Bool? {
    value(name)?.bool ?? defaultValue
  }

  public func boolean(_ name: String, default defaultValue: Bool) -> Bool {
    value(name)?.bool ?? defaultValue
  }

  public func integer(_ name: String, default defaultValue: Int? = nil) -> Int? {
    value(name)?.integer ?? defaultValue
  }

  public func number(_ name: String, default defaultValue: Double? = nil) -> Double? {
    value(name)?.number ?? defaultValue
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

  /// Applies every operation to a detached wire snapshot, then reconciles the
  /// materialized tree once. A malformed later operation therefore cannot
  /// leave earlier operations partially applied.
  public func applyPatch(_ patch: [RufletValue], notify: Bool = true) throws {
    guard patch.count >= 2 else { throw RufletPatchError.malformedPatch }
    var paths: [Int: [RufletValue]] = [:]
    try buildPatchPaths(patch[0], path: [], result: &paths)

    var snapshot = RufletValue.map(properties)
    for encodedOperation in patch.dropFirst() {
      guard let operation = encodedOperation.array,
            let opcode = operation.first?.integer,
            let operationType = RufletPatchOperation(rawValue: opcode)
      else { throw RufletPatchError.malformedOperation }

      switch operationType {
      case .replace, .add, .remove:
        let expectedCount = operationType == .remove ? 3 : 4
        guard operation.count == expectedCount,
              let targetID = operation[1].integer,
              let path = paths[targetID]
        else { throw RufletPatchError.malformedOperation }
        try mutateSnapshot(
          &snapshot,
          path: path,
          operation: operationType,
          key: operation[2],
          value: operationType == .remove ? nil : operation[3])

      case .move:
        guard operation.count == 5,
              let sourceID = operation[1].integer,
              let destinationID = operation[3].integer,
              let sourcePath = paths[sourceID],
              let destinationPath = paths[destinationID]
        else { throw RufletPatchError.malformedOperation }
        let moved = try removeSnapshotValue(&snapshot, path: sourcePath, key: operation[2])
        try mutateSnapshot(
          &snapshot,
          path: destinationPath,
          operation: .add,
          key: operation[4],
          value: moved)
      }
    }

    guard let patchedProperties = snapshot.map else { throw RufletPatchError.invalidPath }
    var changedPaths: [String] = []
    var changedControls: [RufletControl] = []
    var visibleOwners: [RufletControl] = []
    reconcileProperties(
      patchedProperties,
      changedPaths: &changedPaths,
      changedControls: &changedControls,
      visibleOwners: &visibleOwners)
    finishMutation(
      changedPaths: changedPaths,
      changedControls: changedControls,
      visibleOwners: visibleOwners,
      notify: notify)
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

  private func reconcileProperties(
    _ snapshot: [String: RufletValue],
    changedPaths: inout [String],
    changedControls: inout [RufletControl],
    visibleOwners: inout [RufletControl]
  ) {
    for key in materializedProperties.keys where snapshot[key] == nil {
      materializedProperties.removeValue(forKey: key)
      recordChange(
        path: key,
        propertyName: key,
        owner: self,
        changedPaths: &changedPaths,
        changedControls: &changedControls,
        visibleOwners: &visibleOwners)
    }
    for (key, value) in snapshot where key != "_i" && key != "_c" {
      if var existing = materializedProperties[key] {
        reconcileValue(
          &existing,
          incoming: value,
          owner: self,
          path: key,
          propertyName: key,
          changedPaths: &changedPaths,
          changedControls: &changedControls,
          visibleOwners: &visibleOwners)
        materializedProperties[key] = existing
      } else {
        materializedProperties[key] = materialize(value, parent: self)
        recordChange(
          path: key,
          propertyName: key,
          owner: self,
          changedPaths: &changedPaths,
          changedControls: &changedControls,
          visibleOwners: &visibleOwners)
      }
    }
    synchronizeWireProperties()
  }

  private func reconcileValue(
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
      var properties = incomingMap
      properties.removeValue(forKey: "_i")
      properties.removeValue(forKey: "_c")
      control.reconcileProperties(
        properties,
        changedPaths: &changedPaths,
        changedControls: &changedControls,
        visibleOwners: &visibleOwners)

    case (.map(let oldMap), .map(let incomingMap)):
      var newMap = oldMap
      var structureChanged = false
      for key in oldMap.keys where incomingMap[key] == nil {
        newMap.removeValue(forKey: key)
        structureChanged = true
      }
      for (key, value) in incomingMap {
        if var existing = newMap[key] {
          reconcileValue(
            &existing,
            incoming: value,
            owner: owner,
            path: "\(path).\(key)",
            propertyName: key,
            changedPaths: &changedPaths,
            changedControls: &changedControls,
            visibleOwners: &visibleOwners)
          newMap[key] = existing
        } else {
          newMap[key] = materialize(value, parent: owner)
          structureChanged = true
        }
      }
      destination = .map(newMap)
      if structureChanged {
        recordChange(
          path: path,
          propertyName: propertyName,
          owner: owner,
          changedPaths: &changedPaths,
          changedControls: &changedControls,
          visibleOwners: &visibleOwners)
      }

    case (.keyedMap(let oldMap), _):
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
      var newMap = oldMap
      var structureChanged = false
      for key in oldMap.keys where incomingMap[key] == nil {
        newMap.removeValue(forKey: key)
        structureChanged = true
      }
      for (key, value) in incomingMap {
        if var existing = newMap[key] {
          reconcileValue(
            &existing,
            incoming: value,
            owner: owner,
            path: "\(path).\(key.pathDescription)",
            propertyName: key.pathDescription,
            changedPaths: &changedPaths,
            changedControls: &changedControls,
            visibleOwners: &visibleOwners)
          newMap[key] = existing
        } else {
          newMap[key] = materialize(value, parent: owner)
          structureChanged = true
        }
      }
      destination = .keyedMap(newMap)
      if structureChanged {
        recordChange(
          path: path,
          propertyName: propertyName,
          owner: owner,
          changedPaths: &changedPaths,
          changedControls: &changedControls,
          visibleOwners: &visibleOwners)
      }

    case (.array(let oldValues), .array(let incomingValues)):
      var unused = oldValues
      var newValues: [RufletMaterializedValue] = []
      var structuralIdentity: [String] = []
      for (index, incomingValue) in incomingValues.enumerated() {
        if let controlID = incomingValue.map?["_i"]?.integer,
           let existingIndex = unused.firstIndex(where: { value in
             guard case .control(let control) = value else { return false }
             return control.id == controlID
           }) {
          var existing = unused.remove(at: existingIndex)
          reconcileValue(
            &existing,
            incoming: incomingValue,
            owner: owner,
            path: "\(path).\(index)",
            propertyName: String(index),
            changedPaths: &changedPaths,
            changedControls: &changedControls,
            visibleOwners: &visibleOwners)
          newValues.append(existing)
          structuralIdentity.append("c:\(controlID)")
        } else if index < oldValues.count {
          var existing = oldValues[index]
          reconcileValue(
            &existing,
            incoming: incomingValue,
            owner: owner,
            path: "\(path).\(index)",
            propertyName: String(index),
            changedPaths: &changedPaths,
            changedControls: &changedControls,
            visibleOwners: &visibleOwners)
          newValues.append(existing)
          structuralIdentity.append("v:\(rufletStableValueDescription(incomingValue))")
        } else {
          newValues.append(materialize(incomingValue, parent: owner))
          structuralIdentity.append("v:\(rufletStableValueDescription(incomingValue))")
        }
      }
      let oldIdentity = oldValues.map { value -> String in
        if case .control(let control) = value { return "c:\(control.id)" }
        return "v:\(rufletStableValueDescription(value.wireValue))"
      }
      destination = .array(newValues)
      if oldIdentity != structuralIdentity {
        recordChange(
          path: path,
          propertyName: propertyName,
          owner: owner,
          changedPaths: &changedPaths,
          changedControls: &changedControls,
          visibleOwners: &visibleOwners)
      }

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
    if propertyName == "visible", !visibleOwners.contains(where: { $0 === owner }) {
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
    objectWillChange.send()
    let listeners = updateListeners
    listeners.forEach { $0.callback() }
  }

  private func synchronizeWireProperties() {
    properties = materializedProperties.mapValues(\.wireValue)
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

  private func buildPatchPaths(
    _ nodeValue: RufletValue,
    path: [RufletValue],
    result: inout [Int: [RufletValue]]
  ) throws {
    guard let node = nodeValue.array,
          let id = node.first?.integer,
          node.count <= 2
    else { throw RufletPatchError.malformedTreeIndex }
    result[id] = path
    guard node.count == 2 else { return }
    guard let children = node[1].keyedMap else { throw RufletPatchError.malformedTreeIndex }
    for (component, child) in children {
      try buildPatchPaths(child, path: path + [component.value], result: &result)
    }
  }

  private func mutateSnapshot(
    _ root: inout RufletValue,
    path: [RufletValue],
    operation: RufletPatchOperation,
    key: RufletValue,
    value: RufletValue?
  ) throws {
    try mutateSnapshotTarget(&root, path: path) { target in
      try mutateContainer(&target, operation: operation, key: key, value: value)
    }
  }

  private func removeSnapshotValue(
    _ root: inout RufletValue,
    path: [RufletValue],
    key: RufletValue
  ) throws -> RufletValue {
    var removed: RufletValue?
    try mutateSnapshotTarget(&root, path: path) { target in
      removed = try removeFromContainer(&target, key: key)
    }
    guard let removed else { throw RufletPatchError.invalidPath }
    return removed
  }

  private func mutateSnapshotTarget(
    _ value: inout RufletValue,
    path: [RufletValue],
    mutation: (inout RufletValue) throws -> Void
  ) throws {
    guard let component = path.first else {
      try mutation(&value)
      return
    }
    let remaining = Array(path.dropFirst())
    if let name = component.text {
      if var map = value.map, var child = map[name] {
        try mutateSnapshotTarget(&child, path: remaining, mutation: mutation)
        map[name] = child
        value = .map(map)
        return
      }
      if var map = value.keyedMap, var child = map[.string(name)] {
        try mutateSnapshotTarget(&child, path: remaining, mutation: mutation)
        map[.string(name)] = child
        value = .keyedMap(map)
        return
      }
    }
    if let index = component.integer, var list = value.array, list.indices.contains(index) {
      var child = list[index]
      try mutateSnapshotTarget(&child, path: remaining, mutation: mutation)
      list[index] = child
      value = .array(list)
      return
    }
    if let integer = component.integer,
       var map = value.keyedMap,
       var child = map[.int(Int64(integer))] {
      try mutateSnapshotTarget(&child, path: remaining, mutation: mutation)
      map[.int(Int64(integer))] = child
      value = .keyedMap(map)
      return
    }
    throw RufletPatchError.invalidPath
  }

  private func mutateContainer(
    _ container: inout RufletValue,
    operation: RufletPatchOperation,
    key: RufletValue,
    value: RufletValue?
  ) throws {
    if var list = container.array, let index = key.integer {
      switch operation {
      case .replace:
        guard list.indices.contains(index), let value else { throw RufletPatchError.invalidPath }
        list[index] = value
      case .add:
        guard index >= 0, index <= list.count, let value else { throw RufletPatchError.invalidPath }
        list.insert(value, at: index)
      case .remove:
        guard list.indices.contains(index) else { throw RufletPatchError.invalidPath }
        list.remove(at: index)
      case .move: throw RufletPatchError.malformedOperation
      }
      container = .array(list)
      return
    }
    if var map = container.map, let name = key.text {
      switch operation {
      case .remove: guard map.removeValue(forKey: name) != nil else { throw RufletPatchError.invalidPath }
      case .replace: guard map[name] != nil, let value else { throw RufletPatchError.invalidPath }; map[name] = value
      case .add: guard let value else { throw RufletPatchError.invalidPath }; map[name] = value
      case .move: throw RufletPatchError.malformedOperation
      }
      container = .map(map)
      return
    }
    if var map = container.keyedMap, let mapKey = RufletMapKey(value: key) {
      switch operation {
      case .remove: guard map.removeValue(forKey: mapKey) != nil else { throw RufletPatchError.invalidPath }
      case .replace: guard map[mapKey] != nil, let value else { throw RufletPatchError.invalidPath }; map[mapKey] = value
      case .add: guard let value else { throw RufletPatchError.invalidPath }; map[mapKey] = value
      case .move: throw RufletPatchError.malformedOperation
      }
      container = .keyedMap(map)
      return
    }
    throw RufletPatchError.invalidPath
  }

  private func removeFromContainer(_ container: inout RufletValue, key: RufletValue) throws -> RufletValue {
    if var list = container.array, let index = key.integer, list.indices.contains(index) {
      let value = list.remove(at: index)
      container = .array(list)
      return value
    }
    if var map = container.map, let name = key.text, let value = map.removeValue(forKey: name) {
      container = .map(map)
      return value
    }
    if var map = container.keyedMap,
       let mapKey = RufletMapKey(value: key),
       let value = map.removeValue(forKey: mapKey) {
      container = .keyedMap(map)
      return value
    }
    throw RufletPatchError.invalidPath
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
