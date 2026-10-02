// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

import class Foundation.ProcessInfo

private let cmakeExcludes = ["CMakeLists.txt"]

let package = Package(
  name: "swift-toolchain-sarif",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(
      name: "SARIF",
      targets: ["SARIF", "SARIFMerge", "SARIFRecords"],
    ),
    .library(name: "ImmutableJSON", targets: ["ImmutableJSON"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-collections.git",
      .upToNextMajor(from: "1.1.6"))
  ],
  targets: [
    .target(
      name: "ImmutableJSON",
      dependencies: [],
      exclude: cmakeExcludes,
    ),
    .target(
      name: "SARIFRecords",
      dependencies: [
        .product(name: "OrderedCollections", package: "swift-collections")
      ],
      exclude: cmakeExcludes + [
        "SARIFRecords.md"
      ],
    ),
    .target(
      name: "SARIF",
      dependencies: [
        "ImmutableJSON",
        "SARIFRecords",
        .product(name: "BitCollections", package: "swift-collections"),
        .product(name: "OrderedCollections", package: "swift-collections"),
      ],
      exclude: cmakeExcludes,
    ),
    .target(
      name: "SARIFMerge",
      dependencies: [
        "SARIF",
        "SARIFRecords",
        .product(name: "OrderedCollections", package: "swift-collections"),
      ],
      exclude: cmakeExcludes,
    ),
    .target(
      name: "SARIFTestUtilities",
      dependencies: [
        "ImmutableJSON"
      ],
    ),
    .testTarget(
      name: "SARIFRecordsTests",
      dependencies: [
        "ImmutableJSON",
        "SARIFRecords",
        "SARIFTestUtilities",
      ],
    ),
    .testTarget(
      name: "SARIFTests",
      dependencies: [
        "ImmutableJSON",
        "SARIF",
        "SARIFTestUtilities",
      ],
      resources: [
        .copy("Resources")
      ],
    ),
    .testTarget(
      name: "SARIFMergeTests",
      dependencies: [
        "ImmutableJSON",
        "SARIF",
        "SARIFMerge",
        "SARIFTestUtilities",
      ],
      resources: [
        .copy("Resources")
      ],
    ),
  ],
  swiftLanguageModes: [.v6]
)
