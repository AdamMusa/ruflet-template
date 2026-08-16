// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "RufletApple",
  platforms: [
    .iOS(.v15),
    .macOS("13.1"),
  ],
  products: [
    .library(name: "RufletProtocol", targets: ["RufletProtocol"]),
    .library(name: "RufletEngine", targets: ["RufletEngine"]),
    .library(name: "RufletApple", targets: ["RufletApple"]),
    .library(name: "RufletAds", targets: ["RufletAds"]),
    .library(name: "RufletAudio", targets: ["RufletAudio"]),
    .library(name: "RufletAudioRecorder", targets: ["RufletAudioRecorder"]),
    .library(name: "RufletCamera", targets: ["RufletCamera"]),
    .library(name: "RufletCharts", targets: ["RufletCharts"]),
    .library(name: "RufletCodeEditor", targets: ["RufletCodeEditor"]),
    .library(name: "RufletColorPickers", targets: ["RufletColorPickers"]),
    .library(name: "RufletDataTable2", targets: ["RufletDataTable2"]),
    .library(name: "RufletFlashlight", targets: ["RufletFlashlight"]),
    .library(name: "RufletGeolocator", targets: ["RufletGeolocator"]),
    .library(name: "RufletPermissionHandler", targets: ["RufletPermissionHandler"]),
    .library(name: "RufletQRScanner", targets: ["RufletQRScanner"]),
    .library(name: "RufletSecureStorage", targets: ["RufletSecureStorage"]),
    .library(name: "RufletSpinKit", targets: ["RufletSpinKit"]),
    .library(name: "RufletLottie", targets: ["RufletLottie"]),
    .library(name: "RufletMap", targets: ["RufletMap"]),
    .library(name: "RufletRive", targets: ["RufletRive"]),
    .library(name: "RufletWebView", targets: ["RufletWebView"]),
    .library(name: "RufletVideo", targets: ["RufletVideo"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
      exact: "13.7.0"),
    .package(url: "https://github.com/airbnb/lottie-ios.git", exact: "4.6.1"),
    .package(url: "https://github.com/rive-app/rive-ios.git", exact: "6.9.5"),
    .package(url: "https://github.com/swiftlang/swift-markdown.git", exact: "0.7.3"),
    .package(url: "https://github.com/mgriebling/SwiftMath.git", exact: "1.7.3"),
  ],
  targets: [
    .target(
      name: "MaterialColorUtilities",
      path: "Vendor/MaterialColorUtilities/Sources/MaterialColorUtilities"),
    .target(name: "RufletProtocol"),
    .target(
      name: "RufletEngine",
      dependencies: [
        "MaterialColorUtilities",
        "RufletProtocol",
        .product(name: "Markdown", package: "swift-markdown"),
        .product(name: "SwiftMath", package: "SwiftMath"),
      ],
      resources: [.process("Resources")]),
    .target(name: "RufletApple", dependencies: ["RufletEngine", "RufletProtocol"]),
    .target(
      name: "RufletAds",
      dependencies: [
        "RufletEngine",
        "RufletProtocol",
        .product(
          name: "GoogleMobileAds",
          package: "swift-package-manager-google-mobile-ads",
          condition: .when(platforms: [.iOS])),
      ],
      path: "Sources/RufletExtensions/RufletAds"),
    .target(
      name: "RufletAudio",
      dependencies: ["RufletEngine", "RufletProtocol"],
      path: "Sources/RufletExtensions/RufletAudio"),
    .target(
      name: "RufletAudioRecorder",
      dependencies: ["RufletEngine", "RufletProtocol"],
      path: "Sources/RufletExtensions/RufletAudioRecorder"),
    .target(
      name: "RufletCamera",
      dependencies: ["RufletEngine", "RufletProtocol"],
      path: "Sources/RufletExtensions/RufletCamera"),
    .target(
      name: "RufletCharts",
      dependencies: ["RufletEngine", "RufletProtocol"],
      path: "Sources/RufletExtensions/RufletCharts"),
    .target(
      name: "RufletCodeEditor",
      dependencies: ["RufletEngine", "RufletProtocol"],
      path: "Sources/RufletExtensions/RufletCodeEditor"),
    .target(
      name: "RufletColorPickers",
      dependencies: ["RufletEngine", "RufletProtocol"],
      path: "Sources/RufletExtensions/RufletColorPickers"),
    .target(
      name: "RufletDataTable2",
      dependencies: ["RufletEngine", "RufletProtocol"],
      path: "Sources/RufletExtensions/RufletDataTable2"),
    .target(
      name: "RufletFlashlight",
      dependencies: ["RufletEngine", "RufletProtocol"],
      path: "Sources/RufletExtensions/RufletFlashlight"),
    .target(
      name: "RufletGeolocator",
      dependencies: ["RufletEngine", "RufletProtocol"],
      path: "Sources/RufletExtensions/RufletGeolocator"),
    .target(
      name: "RufletPermissionHandler",
      dependencies: ["RufletEngine", "RufletProtocol"],
      path: "Sources/RufletExtensions/RufletPermissionHandler"),
    .target(
      name: "RufletQRScanner",
      dependencies: ["RufletEngine", "RufletProtocol"],
      path: "Sources/RufletExtensions/RufletQRScanner"),
    .target(
      name: "RufletSecureStorage",
      dependencies: ["RufletEngine", "RufletProtocol"],
      path: "Sources/RufletExtensions/RufletSecureStorage"),
    .target(
      name: "RufletSpinKit",
      dependencies: ["RufletEngine", "RufletProtocol"],
      path: "Sources/RufletExtensions/RufletSpinKit"),
    .target(
      name: "RufletLottie",
      dependencies: [
        "RufletEngine",
        "RufletProtocol",
        .product(name: "Lottie", package: "lottie-ios"),
      ],
      path: "Sources/RufletExtensions/RufletLottie"),
    .target(
      name: "RufletMap",
      dependencies: ["RufletEngine", "RufletProtocol"],
      path: "Sources/RufletExtensions/RufletMap"),
    .target(
      name: "RufletRive",
      dependencies: [
        "RufletEngine",
        "RufletProtocol",
        .product(name: "RiveRuntime", package: "rive-ios"),
      ],
      path: "Sources/RufletExtensions/RufletRive"),
    .target(
      name: "RufletWebView",
      dependencies: ["RufletEngine", "RufletProtocol"],
      path: "Sources/RufletExtensions/RufletWebView"),
    .target(
      name: "RufletVideo",
      dependencies: ["RufletEngine", "RufletProtocol"],
      path: "Sources/RufletExtensions/RufletVideo"),
    .testTarget(name: "RufletProtocolTests", dependencies: ["RufletProtocol"]),
    .testTarget(name: "RufletEngineTests", dependencies: ["RufletEngine", "RufletProtocol"]),
    .testTarget(
      name: "RufletExtensionsTests",
      dependencies: [
        "RufletEngine", "RufletAds", "RufletAudio", "RufletAudioRecorder", "RufletCamera",
        "RufletCharts", "RufletCodeEditor", "RufletColorPickers", "RufletDataTable2",
        "RufletFlashlight", "RufletGeolocator", "RufletLottie", "RufletMap",
        "RufletPermissionHandler", "RufletQRScanner", "RufletRive", "RufletSecureStorage",
        "RufletSpinKit",
        "RufletVideo", "RufletWebView",
      ],
      path: "Tests/RufletExtensionsTests"),
  ]
)
