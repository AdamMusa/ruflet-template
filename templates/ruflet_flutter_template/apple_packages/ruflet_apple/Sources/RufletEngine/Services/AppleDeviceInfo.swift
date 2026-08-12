import Foundation
import RufletProtocol

#if canImport(Darwin)
  import Darwin
#endif
#if canImport(UIKit)
  import UIKit
#endif
#if canImport(IOKit)
  import IOKit
#endif

/// Native counterpart of Flet 0.80.5's `DeviceInfoExtension.asMap()` for
/// device_info_plus 12.3.0. Keys intentionally use Flet's snake_case adapter
/// names rather than device_info_plus's internal camelCase channel names.
@MainActor
public enum FletAppleDeviceInfoSemantics {
  public static let macOSKeys: Set<String> = [
    "active_cpus", "arch", "computer_name", "cpu_frequency", "host_name",
    "kernel_version", "major_version", "memory_size", "minor_version", "model",
    "model_name", "os_release", "patch_version", "system_guid", "locales",
  ]

  public static let iOSKeys: Set<String> = [
    "available_ram_size", "free_disk_size", "is_ios_app_on_mac", "is_physical_device",
    "localized_model", "model", "model_name", "name", "physical_ram_size",
    "system_name", "system_version", "total_disk_size", "utsname",
    "identifier_for_vendor", "locales",
  ]

  public static func payload() -> [String: RufletValue] {
    #if canImport(UIKit)
      return iOSPayload()
    #elseif os(macOS)
      return macOSPayload()
    #else
      return [:]
    #endif
  }

  public static func locales(_ identifiers: [String] = Locale.preferredLanguages)
    -> RufletValue
  {
    .array(
      identifiers.map { identifier in
        let components = explicitLocaleComponents(identifier)
        return .map([
          "language_code": .string(components.language),
          "country_code": components.country.map(RufletValue.string) ?? .null,
          "script_code": components.script.map(RufletValue.string) ?? .null,
        ])
      })
  }

  /// Foundation may infer `Latn` for `en-US`; Flutter only reports a script
  /// when it was explicitly present in the platform locale identifier.
  private static func explicitLocaleComponents(_ identifier: String)
    -> (language: String, country: String?, script: String?)
  {
    let base =
      identifier.split(separator: "@", maxSplits: 1).first.map(String.init)
      ?? identifier
    let tokens = base.replacingOccurrences(of: "_", with: "-").split(separator: "-")
    let language = tokens.first.map { String($0).lowercased() } ?? identifier
    var country: String?
    var script: String?
    for tokenValue in tokens.dropFirst() {
      let token = String(tokenValue)
      if token.count == 4, token.allSatisfy(\.isLetter), script == nil {
        script = token.prefix(1).uppercased() + token.dropFirst().lowercased()
      } else if (token.count == 2 && token.allSatisfy(\.isLetter))
        || (token.count == 3 && token.allSatisfy(\.isNumber)), country == nil
      {
        country = token.uppercased()
      }
    }
    return (language, country, script)
  }

  #if os(macOS)
    public static func macOSPayload() -> [String: RufletValue] {
      let version = ProcessInfo.processInfo.operatingSystemVersion
      let model = sysctlString("hw.model")
      return [
        "active_cpus": .int(sysctlInteger("hw.availcpu", as: Int32.self)),
        "arch": .string(sysctlString("hw.machine")),
        "computer_name": .string(
          Host.current().localizedName ?? sysctlString("kern.hostname")),
        "cpu_frequency": .int(sysctlInteger("hw.cpufrequency", as: Int64.self)),
        "host_name": .string(sysctlString("kern.ostype")),
        "kernel_version": .string(sysctlString("kern.version")),
        "major_version": .int(Int64(version.majorVersion)),
        "memory_size": .int(sysctlInteger("hw.memsize", as: UInt64.self)),
        "minor_version": .int(Int64(version.minorVersion)),
        "model": .string(model),
        "model_name": .string(modelName(forMacIdentifier: model)),
        "os_release": .string(ProcessInfo.processInfo.operatingSystemVersionString),
        "patch_version": .int(Int64(version.patchVersion)),
        "system_guid": systemGUID().map(RufletValue.string) ?? .null,
        "locales": locales(),
      ]
    }
  #endif

  #if canImport(UIKit)
    public static func iOSPayload() -> [String: RufletValue] {
      let device = UIDevice.current
      let process = ProcessInfo.processInfo
      let system = systemIdentity()
      let machine =
        ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
        ?? system.machine
      let disk = diskSizes()
      #if targetEnvironment(simulator)
        let isPhysicalDevice = false
      #else
        let isPhysicalDevice = true
      #endif
      let isIOSAppOnMac: Bool
      if #available(iOS 14.0, *) {
        isIOSAppOnMac = process.isiOSAppOnMac
      } else {
        isIOSAppOnMac = false
      }
      return [
        "available_ram_size": .int(availableMemoryInMegabytes()),
        "free_disk_size": .int(disk.free),
        "is_ios_app_on_mac": .bool(isIOSAppOnMac),
        "is_physical_device": .bool(isPhysicalDevice),
        "localized_model": .string(device.localizedModel),
        "model": .string(device.model),
        "model_name": .string(modelName(forIOSIdentifier: machine)),
        "name": .string(device.name),
        "physical_ram_size": .int(Int64(process.physicalMemory / 1_048_576)),
        "system_name": .string(device.systemName),
        "system_version": .string(device.systemVersion),
        "total_disk_size": .int(disk.total),
        "utsname": .map([
          "machine": .string(machine),
          "node_name": .string(system.nodeName),
          "release": .string(system.release),
          "sys_name": .string(system.systemName),
          "version": .string(system.version),
        ]),
        "identifier_for_vendor": (device.identifierForVendor?.uuidString)
          .map(RufletValue.string) ?? .null,
        "locales": locales(),
      ]
    }

    private static func diskSizes() -> (free: Int64, total: Int64) {
      guard
        let attributes = try? FileManager.default.attributesOfFileSystem(
          forPath: NSHomeDirectory())
      else { return (-1, -1) }
      return (
        (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? -1,
        (attributes[.systemSize] as? NSNumber)?.int64Value ?? -1
      )
    }

    private static func availableMemoryInMegabytes() -> Int64 {
      var pageSize: vm_size_t = 0
      let host = mach_host_self()
      guard host_page_size(host, &pageSize) == KERN_SUCCESS else { return -1 }
      var statistics = vm_statistics_data_t()
      var count = mach_msg_type_number_t(
        MemoryLayout<vm_statistics_data_t>.size / MemoryLayout<integer_t>.size)
      let result = withUnsafeMutablePointer(to: &statistics) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
          host_statistics(host, HOST_VM_INFO, $0, &count)
        }
      }
      guard result == KERN_SUCCESS else { return -1 }
      return Int64(statistics.free_count) * Int64(pageSize) / 1_048_576
    }
  #endif

  private struct SystemIdentity {
    let systemName: String
    let nodeName: String
    let release: String
    let version: String
    let machine: String
  }

  private static func systemIdentity() -> SystemIdentity {
    var value = utsname()
    guard uname(&value) == 0 else {
      return SystemIdentity(
        systemName: "", nodeName: "", release: "", version: "", machine: "")
    }
    return SystemIdentity(
      systemName: tupleString(value.sysname),
      nodeName: tupleString(value.nodename),
      release: tupleString(value.release),
      version: tupleString(value.version),
      machine: tupleString(value.machine))
  }

  private static func tupleString<T>(_ value: T) -> String {
    withUnsafePointer(to: value) {
      $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) {
        String(cString: $0)
      }
    }
  }

  #if os(macOS)
    private static func sysctlString(_ name: String) -> String {
      var size = 0
      guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }
      var bytes = [CChar](repeating: 0, count: size)
      guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return "" }
      return String(cString: bytes)
    }

    private static func sysctlInteger<T: FixedWidthInteger>(
      _ name: String, as type: T.Type
    ) -> Int64 {
      var value: T = 0
      var size = MemoryLayout<T>.size
      guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return 0 }
      return Int64(clamping: value)
    }

    private static func systemGUID() -> String? {
      #if canImport(IOKit)
        let port: mach_port_t
        if #available(macOS 12.0, *) {
          port = kIOMainPortDefault
        } else {
          port = kIOMasterPortDefault
        }
        let service = IOServiceGetMatchingService(
          port, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard
          let property = IORegistryEntryCreateCFProperty(
            service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)
        else { return nil }
        return property.takeRetainedValue() as? String
      #else
        return nil
      #endif
    }
  #endif

  public static func modelName(forMacIdentifier identifier: String) -> String {
    switch identifier {
    // MacBook models (2015 and later)
    case "MacBook8,1": return "MacBook (12-inch, 2015)"
    case "MacBook9,1": return "MacBook (12-inch, 2016)"
    case "MacBook10,1": return "MacBook (12-inch, 2017)"

    // MacBook Air models (2013 and later)
    case "MacBookAir6,1": return "MacBook Air (11-inch, 2013)"
    case "MacBookAir6,2": return "MacBook Air (13-inch, 2013)"
    case "MacBookAir7,1": return "MacBook Air (11-inch, 2015)"
    case "MacBookAir7,2": return "MacBook Air (13-inch, 2015-2017)"
    case "MacBookAir8,1": return "MacBook Air (13-inch, 2018)"
    case "MacBookAir8,2": return "MacBook Air (13-inch, 2019)"
    case "MacBookAir9,1": return "MacBook Air (13-inch, 2020)"
    case "MacBookAir10,1": return "MacBook Air (13-inch, 2020)"
    case "Mac14,2": return "MacBook Air (13-inch, 2022)"
    case "Mac14,15": return "MacBook Air (15-inch, 2023)"
    case "Mac15,12": return "MacBook Air (13-inch, 2024)"
    case "Mac15,13": return "MacBook Air (15-inch, 2024)"
    case "Mac16,12": return "MacBook Air (13-inch, 2025)"
    case "Mac16,13": return "MacBook Air (15-inch, 2025)"

    // MacBook Pro models (2012 and later)
    case "MacBookPro10,1": return "MacBook Pro (15-inch, 2012-2013)"
    case "MacBookPro10,2": return "MacBook Pro (13-inch, 2012-2013)"
    case "MacBookPro11,1": return "MacBook Pro (13-inch, 2013-2014)"
    case "MacBookPro11,2", "MacBookPro11,3": return "MacBook Pro (15-inch, 2013-2014)"
    case "MacBookPro11,4", "MacBookPro11,5": return "MacBook Pro (15-inch, 2015)"
    case "MacBookPro12,1": return "MacBook Pro (13-inch, 2015)"
    case "MacBookPro13,1": return "MacBook Pro (13-inch, 2016)"
    case "MacBookPro13,2": return "MacBook Pro (13-inch, 2016)"
    case "MacBookPro13,3": return "MacBook Pro (15-inch, 2016)"
    case "MacBookPro14,1": return "MacBook Pro (13-inch, 2017)"
    case "MacBookPro14,2": return "MacBook Pro (13-inch, 2017)"
    case "MacBookPro14,3": return "MacBook Pro (15-inch, 2017)"
    case "MacBookPro15,1", "MacBookPro15,3": return "MacBook Pro (15-inch, 2018-2019)"
    case "MacBookPro15,2": return "MacBook Pro (13-inch, 2018-2019)"
    case "MacBookPro15,4": return "MacBook Pro (13-inch, 2019)"
    case "MacBookPro16,1", "MacBookPro16,4": return "MacBook Pro (16-inch, 2019)"
    case "MacBookPro16,2": return "MacBook Pro (13-inch, 2019)"
    case "MacBookPro16,3": return "MacBook Pro (13-inch, 2020)"
    case "MacBookPro17,1": return "MacBook Pro (13-inch, 2020)"
    case "MacBookPro18,1": return "MacBook Pro (14-inch, 2021)"
    case "MacBookPro18,2": return "MacBook Pro (16-inch, 2021)"
    case "MacBookPro18,3": return "MacBook Pro (16-inch, 2021)"
    case "Mac14,5", "Mac14,9": return "MacBook Pro (14-inch, 2023)"
    case "Mac14,6", "Mac14,10": return "MacBook Pro (14-inch, 2023)"
    case "Mac14,7": return "MacBook Pro (13-inch, 2022)"
    case "Mac15,3": return "MacBook Pro (14-inch, 2023)"
    case "Mac15,6", "Mac15,8", "Mac15,10": return "MacBook Pro (14-inch, 2023)"
    case "Mac15,7", "Mac15,9", "Mac15,11": return "MacBook Pro (16-inch, 2023)"
    case "Mac16,1", "Mac16,6", "Mac16,8": return "MacBook Pro (14-inch, 2024)"
    case "Mac16,5", "Mac16,7": return "MacBook Pro (16-inch, 2024)"
    case "Mac17,2": return "MacBook Pro (14-inch, 2025)"

    // iMac models (2013 and later)
    case "iMac13,1": return "iMac (21.5-inch, 2013)"
    case "iMac13,2": return "iMac (27-inch, 2013)"
    case "iMac14,1": return "iMac (21.5-inch, 2014)"
    case "iMac14,2": return "iMac (27-inch, 2014)"
    case "iMac14,4": return "iMac (21.5-inch, 2014)"
    case "iMac15,1": return "iMac (27-inch, 2014-2015)"
    case "iMac16,1", "iMac16,2": return "iMac (21.5-inch, 2015)"
    case "iMac17,1": return "iMac (27-inch, 2015)"
    case "iMac18,1": return "iMac (21.5-inch, 2017)"
    case "iMac18,2": return "iMac (21.5-inch, 2017)"
    case "iMac18,3": return "iMac (27-inch, 2017)"
    case "iMac19,1": return "iMac (27-inch, 2019)"
    case "iMac19,2": return "iMac (21.5-inch, 2019)"
    case "iMac20,1", "iMac20,2": return "iMac (27-inch, 2020)"
    case "iMac21,1", "iMac21,2": return "iMac (24-inch, 2021)"
    case "Mac15,4", "Mac15,5": return "iMac (24-inch, 2023)"
    case "Mac16,2", "Mac16,3": return "iMac (24-inch, 2024)"

    // Mac mini models (2012 and later)
    case "MacMini6,1", "MacMini6,2": return "Mac mini (2012)"
    case "MacMini7,1": return "Mac mini (2014)"
    case "MacMini8,1": return "Mac mini (2018)"
    case "MacMini9,1": return "Mac mini (2020)"
    case "Mac14,12": return "Mac mini (2023)"
    case "Mac14,3": return "Mac mini (2023)"
    case "Mac16,11", "Mac16,10": return "Mac mini (2024)"

    // Mac Pro models (2013 and later)
    case "MacPro6,1": return "Mac Pro (Late 2013)"
    case "MacPro7,1": return "Mac Pro (2019)"
    case "Mac14,8": return "Mac Pro (2023)"

    // iMac Pro
    case "iMacPro1,1": return "iMac Pro (2017)"

    // Mac Studio (2022 and newer)
    case "Mac13,1", "Mac13,2": return "Mac Studio (2022)"
    case "Mac14,13", "Mac14,14": return "Mac Studio (2023)"
    case "Mac15,14", "Mac16,9": return "Mac Studio (2025)"

    default: return "Unknown Model"
    }
  }

  public static func modelName(forIOSIdentifier identifier: String) -> String {
    switch identifier {
    case "iPhone6,1": return "iPhone 5s"
    case "iPhone6,2": return "iPhone 5s"
    case "iPhone7,2": return "iPhone 6"
    case "iPhone7,1": return "iPhone 6 Plus"
    case "iPhone8,1": return "iPhone 6s"
    case "iPhone8,2": return "iPhone 6s Plus"
    case "iPhone9,1", "iPhone9,3": return "iPhone 7"
    case "iPhone9,2", "iPhone9,4": return "iPhone 7 Plus"
    case "iPhone8,4": return "iPhone SE"
    case "iPhone10,1", "iPhone10,4": return "iPhone 8"
    case "iPhone10,2", "iPhone10,5": return "iPhone 8 Plus"
    case "iPhone10,3", "iPhone10,6": return "iPhone X"
    case "iPhone11,2": return "iPhone XS"
    case "iPhone11,4", "iPhone11,6": return "iPhone XS Max"
    case "iPhone11,8": return "iPhone XR"
    case "iPhone12,1": return "iPhone 11"
    case "iPhone12,3": return "iPhone 11 Pro"
    case "iPhone12,5": return "iPhone 11 Pro Max"
    case "iPhone12,8": return "iPhone SE 2"
    case "iPhone13,2": return "iPhone 12"
    case "iPhone13,1": return "iPhone 12 Mini"
    case "iPhone13,3": return "iPhone 12 Pro"
    case "iPhone13,4": return "iPhone 12 Pro Max"
    case "iPhone14,5": return "iPhone 13"
    case "iPhone14,4": return "iPhone 13 Mini"
    case "iPhone14,2": return "iPhone 13 Pro"
    case "iPhone14,3": return "iPhone 13 Pro Max"
    case "iPhone14,6": return "iPhone SE 3"
    case "iPhone14,7": return "iPhone 14"
    case "iPhone14,8": return "iPhone 14 Plus"
    case "iPhone15,2": return "iPhone 14 Pro"
    case "iPhone15,3": return "iPhone 14 Pro Max"
    case "iPhone15,4": return "iPhone 15"
    case "iPhone15,5": return "iPhone 15 Plus"
    case "iPhone16,1": return "iPhone 15 Pro"
    case "iPhone16,2": return "iPhone 15 Pro Max"
    case "iPhone17,3": return "iPhone 16"
    case "iPhone17,4": return "iPhone 16 Plus"
    case "iPhone17,1": return "iPhone 16 Pro"
    case "iPhone17,2": return "iPhone 16 Pro Max"
    case "iPhone17,5": return "iPhone 16e"
    case "iPhone18,3": return "iPhone 17"
    case "iPhone18,1": return "iPhone 17 Pro"
    case "iPhone18,2": return "iPhone 17 Pro Max"
    case "iPhone18,4": return "iPhone Air"
    case "iPad4,1", "iPad4,2", "iPad4,3": return "iPad Air"
    case "iPad5,3", "iPad5,4": return "iPad Air 2"
    case "iPad6,11", "iPad6,12": return "iPad 5"
    case "iPad7,5", "iPad7,6": return "iPad 6"
    case "iPad11,3", "iPad11,4": return "iPad Air 3"
    case "iPad7,11", "iPad7,12": return "iPad 7"
    case "iPad11,6", "iPad11,7": return "iPad 8"
    case "iPad12,1", "iPad12,2": return "iPad 9"
    case "iPad13,18", "iPad13,19": return "iPad 10"
    case "iPad13,1", "iPad13,2": return "iPad Air 4"
    case "iPad13,16", "iPad13,17": return "iPad Air 5"
    case "iPad14,8", "iPad14,9": return "iPad Air 11-Inch M2"
    case "iPad14,10", "iPad14,11": return "iPad Air 13-Inch M2"
    case "iPad2,5", "iPad2,6", "iPad2,7": return "iPad Mini"
    case "iPad4,4", "iPad4,5", "iPad4,6": return "iPad Mini 2"
    case "iPad4,7", "iPad4,8", "iPad4,9": return "iPad Mini 3"
    case "iPad5,1", "iPad5,2": return "iPad Mini 4"
    case "iPad11,1", "iPad11,2": return "iPad Mini 5"
    case "iPad14,1", "iPad14,2": return "iPad Mini 6"
    case "iPad6,3", "iPad6,4": return "iPad Pro 9-Inch"
    case "iPad6,7", "iPad6,8": return "iPad Pro 12-Inch"
    case "iPad7,1", "iPad7,2": return "iPad Pro 12-Inch 2"
    case "iPad7,3", "iPad7,4": return "iPad Pro 10-Inch"
    case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4": return "iPad Pro 11-Inch"
    case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8": return "iPad Pro 12-Inch 3"
    case "iPad8,9", "iPad8,10": return "iPad Pro 11-Inch 2"
    case "iPad8,11", "iPad8,12": return "iPad Pro 12-Inch 4"
    case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7": return "iPad Pro 11-Inch 3"
    case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": return "iPad Pro 12-Inch 5"
    case "iPad14,3", "iPad14,4": return "iPad Pro 11-Inch 4"
    case "iPad14,5", "iPad14,6": return "iPad Pro 12-Inch 6"
    case "iPad16,3", "iPad16,4": return "iPad Pro 11-Inch (M4)"
    case "iPad16,5", "iPad16,6": return "iPad Pro 13-Inch (M4)"
    case "iPad17,1", "iPad17,2": return "iPad Pro 11-Inch (M5)"
    case "iPad17,3", "iPad17,4": return "iPad Pro 13-Inch (M5)"
    default: return "Unknown device"
    }
  }
}
