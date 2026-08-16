// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "RufletAppExtensions",
  platforms: [
    .iOS(.v16),
    .macOS("13.1"),
  ],
  products: [
    .library(name: "RufletAppExtensions", targets: ["RufletAppExtensions"]),
  ],
  dependencies: [
    .package(path: "../apple_packages/ruflet_apple"),
  ],
  targets: [
    .target(
      name: "RufletAppExtensions",
      dependencies: [
        .product(name: "RufletApple", package: "ruflet_apple"),
      ]),
    .testTarget(
      name: "RufletAppExtensionsTests",
      dependencies: ["RufletAppExtensions"]),
  ])
