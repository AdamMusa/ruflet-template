// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "RufletApple",
  platforms: [
    .iOS(.v15),
    .macOS("13.1")
  ],
  products: [
    // The umbrella an application links: protocol, engine and renderer, with
    // every service that touches no privacy-gated framework.
    .library(name: "RufletApple", targets: ["RufletApple"]),

    // Optional service modules. Each pulls in a framework Apple gates behind a
    // usage string and flags during review, so they are linked on demand
    // rather than compiled into every app.
    .library(name: "RufletMotion", targets: ["RufletMotion"]),
    .library(name: "RufletLocation", targets: ["RufletLocation"]),
    .library(name: "RufletMedia", targets: ["RufletMedia"]),
    .library(name: "RufletRive", targets: ["RufletRive"]),
    .library(name: "RufletLottie", targets: ["RufletLottie"]),

    // Available separately for hosts that want the wire layer or the control
    // model without the SwiftUI renderer.
    .library(name: "RufletProtocol", targets: ["RufletProtocol"]),
    .library(name: "RufletEngine", targets: ["RufletEngine"])
  ],
  dependencies: [
    .package(url: "https://github.com/airbnb/lottie-ios.git", exact: "4.6.1"),
    .package(url: "https://github.com/rive-app/rive-ios.git", exact: "6.9.5")
  ],
  targets: [
    // Google's Apache-2.0 Material Color Utilities implementation. Flutter's
    // ColorScheme.fromSeed uses the same HCT/dynamic-colour algorithm.
    .target(name: "MaterialColorUtilities", exclude: ["LICENSE.material-color-utilities"]),
    .target(name: "RufletProtocol"),
    .target(name: "RufletEngine", dependencies: ["RufletProtocol"]),
    .target(
      name: "RufletUI",
      dependencies: ["RufletEngine", "RufletProtocol", "MaterialColorUtilities"]),
    .target(name: "RufletApple", dependencies: ["RufletUI", "RufletEngine", "RufletProtocol"]),

    .target(name: "RufletMotion", dependencies: ["RufletEngine", "RufletProtocol"]),
    .target(name: "RufletLocation", dependencies: ["RufletEngine", "RufletProtocol"]),
    .target(name: "RufletMedia", dependencies: ["RufletUI", "RufletEngine", "RufletProtocol"]),
    .target(
      name: "RufletRive",
      dependencies: [
        "RufletUI", "RufletEngine", "RufletProtocol",
        .product(name: "RiveRuntime", package: "rive-ios")
      ]),
    .target(
      name: "RufletLottie",
      dependencies: [
        "RufletUI", "RufletEngine", "RufletProtocol",
        .product(name: "Lottie", package: "lottie-ios")
      ]),

    .testTarget(
      name: "RufletEngineTests",
      dependencies: [
        "RufletEngine", "RufletProtocol", "RufletUI",
        "RufletMotion", "RufletLocation", "RufletMedia", "RufletRive", "RufletLottie"
      ])
  ])
