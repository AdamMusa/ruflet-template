import Darwin
import Foundation
import RufletProtocol

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Apple-only counterpart of pinned `getDeviceInfo()`.
func getAppleDeviceInfo() -> RufletValue {
  var system = utsname()
  uname(&system)
  let locales: RufletValue = .array(Locale.preferredLanguages.map { identifier in
    let locale = NSLocale(localeIdentifier: identifier)
    let languageCode = locale.object(forKey: .languageCode) as? String
    let countryCode = locale.object(forKey: .countryCode) as? String
    let scriptCode = locale.object(forKey: .scriptCode) as? String
    let localeMap: [String: RufletValue] = [
      "language_code": languageCode.map { .string($0) } ?? .null,
      "country_code": countryCode.map { .string($0) } ?? .null,
      "script_code": scriptCode.map { .string($0) } ?? .null,
    ]
    return .map(localeMap)
  })

  #if os(iOS)
  let device = UIDevice.current
  return .map([
    "available_ram_size": .int(Int64(os_proc_available_memory())),
    "free_disk_size": diskValue(.systemFreeSize),
    "is_ios_app_on_mac": .bool(ProcessInfo.processInfo.isiOSAppOnMac),
    "is_physical_device": .bool(isPhysicalAppleDevice),
    "localized_model": .string(device.localizedModel),
    "model": .string(device.model),
    "model_name": .string(unameString(&system.machine)),
    "name": .string(device.name),
    "physical_ram_size": .int(Int64(ProcessInfo.processInfo.physicalMemory)),
    "system_name": .string(device.systemName),
    "system_version": .string(device.systemVersion),
    "total_disk_size": diskValue(.systemSize),
    "utsname": .map([
      "machine": .string(unameString(&system.machine)),
      "node_name": .string(unameString(&system.nodename)),
      "release": .string(unameString(&system.release)),
      "sys_name": .string(unameString(&system.sysname)),
      "version": .string(unameString(&system.version)),
    ]),
    "identifier_for_vendor": (device.identifierForVendor?.uuidString).map { .string($0) } ?? .null,
    "locales": locales,
  ])
  #elseif os(macOS)
  let version = ProcessInfo.processInfo.operatingSystemVersion
  let machine = unameString(&system.machine)
  return .map([
    "active_cpus": .int(Int64(ProcessInfo.processInfo.activeProcessorCount)),
    "arch": .string(machine),
    "computer_name": .string(Host.current().localizedName ?? ""),
    "cpu_frequency": sysctlInteger("hw.cpufrequency").map(RufletValue.int) ?? .null,
    "host_name": .string(ProcessInfo.processInfo.hostName),
    "kernel_version": .string(unameString(&system.version)),
    "major_version": .int(Int64(version.majorVersion)),
    "memory_size": .int(Int64(ProcessInfo.processInfo.physicalMemory)),
    "minor_version": .int(Int64(version.minorVersion)),
    "model": .string(machine),
    "model_name": .string(machine),
    "os_release": .string(unameString(&system.release)),
    "patch_version": .int(Int64(version.patchVersion)),
    "system_guid": .null,
    "locales": locales,
  ])
  #endif
}

private func unameString<T>(_ field: inout T) -> String {
  withUnsafePointer(to: &field) { pointer in
    pointer.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) {
      String(cString: $0)
    }
  }
}

private enum RufletDiskMetric {
  case systemFreeSize
  case systemSize
}

private func diskValue(_ metric: RufletDiskMetric) -> RufletValue {
  let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
  let key: FileAttributeKey
  switch metric {
  case .systemFreeSize: key = .systemFreeSize
  case .systemSize: key = .systemSize
  }
  guard let number = attributes?[key] as? NSNumber else { return .null }
  return .int(number.int64Value)
}

#if os(iOS)
private var isPhysicalAppleDevice: Bool {
  #if targetEnvironment(simulator)
  false
  #else
  true
  #endif
}
#elseif os(macOS)
private func sysctlInteger(_ name: String) -> Int64? {
  var value: UInt64 = 0
  var size = MemoryLayout<UInt64>.size
  guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
  return Int64(exactly: value)
}
#endif
