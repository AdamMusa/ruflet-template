enum RufletApplePlatform: String, Sendable {
    case iOS
    case macOS
}

func currentApplePlatform() -> RufletApplePlatform {
    #if os(iOS)
    .iOS
    #elseif os(macOS)
    .macOS
    #else
    #error("RufletEngine supports iOS and macOS only")
    #endif
}

func isDesktopPlatform() -> Bool {
    currentApplePlatform() == .macOS
}

func isMacOSDesktop() -> Bool {
    currentApplePlatform() == .macOS
}

func isMobilePlatform() -> Bool {
    currentApplePlatform() == .iOS
}

func isIOSMobile() -> Bool {
    currentApplePlatform() == .iOS
}

func isApplePlatform() -> Bool { true }
