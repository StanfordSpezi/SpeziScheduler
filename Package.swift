// swift-tools-version:6.0

//
// This source file is part of the Stanford Spezi open-source project
// 
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
// 
// SPDX-License-Identifier: MIT
//

import CompilerPluginSupport
import class Foundation.ProcessInfo
import PackageDescription


let package = Package(
    name: "SpeziScheduler",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .visionOS(.v2),
        .watchOS(.v11)
    ],
    products: [
        .library(name: "SpeziScheduler", targets: ["SpeziScheduler"]),
        .library(name: "SpeziSchedulerUI", targets: ["SpeziSchedulerUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/StanfordSpezi/SpeziFoundation", from: "2.0.0"),
        .package(url: "https://github.com/StanfordSpezi/Spezi", from: "1.8.0"),
        .package(url: "https://github.com/StanfordSpezi/SpeziViews", from: "1.7.0"),
        .package(url: "https://github.com/StanfordSpezi/SpeziStorage", from: "1.1.2"),
        .package(url: "https://github.com/StanfordSpezi/SpeziNotifications.git", from: "1.0.2"),
        .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.2.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.0-prerelease-2024-08-14"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.2")
    ] + swiftLintPackage(),
    targets: [
        .macro(
            name: "SpeziSchedulerMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax")
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .target(
            name: "SpeziScheduler",
            dependencies: [
                .target(name: "SpeziSchedulerMacros"),
                .product(name: "SpeziFoundation", package: "SpeziFoundation"),
                .product(name: "Spezi", package: "Spezi"),
                .product(name: "SpeziViews", package: "SpeziViews"),
                .product(name: "SpeziNotifications", package: "SpeziNotifications"),
                .product(name: "SpeziLocalStorage", package: "SpeziStorage"),
                .product(name: "Algorithms", package: "swift-algorithms")
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .target(
            name: "SpeziSchedulerUI",
            dependencies: [
                .target(name: "SpeziScheduler"),
                .product(name: "SpeziViews", package: "SpeziViews")
            ],
            resources: [
                .process("Resources")
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .testTarget(
            name: "SpeziSchedulerTests",
            dependencies: [
                .target(name: "SpeziScheduler"),
                .product(name: "XCTSpezi", package: "Spezi"),
                .product(name: "SpeziLocalStorage", package: "SpeziStorage")
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .testTarget(
            name: "SpeziSchedulerUITests",
            dependencies: [
                .target(name: "SpeziScheduler"),
                .target(name: "SpeziSchedulerUI"),
                .product(name: "XCTSpezi", package: "Spezi"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .testTarget(
            name: "SpeziSchedulerMacrosTest",
            dependencies: [
                "SpeziSchedulerMacros",
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ],
            plugins: [] + swiftLintPlugin()
        )
    ]
)


func swiftLintPlugin() -> [Target.PluginUsage] {
    // Fully quit Xcode and open again with `open --env SPEZI_DEVELOPMENT_SWIFTLINT /Applications/Xcode.app`
    if ProcessInfo.processInfo.environment["SPEZI_DEVELOPMENT_SWIFTLINT"] != nil {
        [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")]
    } else {
        []
    }
}

func swiftLintPackage() -> [PackageDescription.Package.Dependency] {
    if ProcessInfo.processInfo.environment["SPEZI_DEVELOPMENT_SWIFTLINT"] != nil {
        [.package(url: "https://github.com/realm/SwiftLint.git", from: "0.55.1")]
    } else {
        []
    }
}
