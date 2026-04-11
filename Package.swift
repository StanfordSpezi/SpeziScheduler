// swift-tools-version:6.2

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
    products: products(),
    dependencies: dependencies() + swiftLintPackage(),
    targets: targets()
)

func products() -> [Product] {
    var products: [Product] = [
        .library(name: "SpeziScheduler", targets: ["SpeziScheduler"])
    ]
    #if canImport(Darwin)
    products.append(.library(name: "SpeziSchedulerUI", targets: ["SpeziSchedulerUI"]))
    #endif
    return products
}

func dependencies() -> [PackageDescription.Package.Dependency] {
    var dependencies: [PackageDescription.Package.Dependency] = [
        .package(url: "https://github.com/StanfordSpezi/SpeziFoundation.git", from: "2.7.2"),
        .package(url: "https://github.com/StanfordSpezi/Spezi.git", from: "1.10.2"),
        .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.2.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"605.0.0"),
        .package(url: "https://github.com/StanfordBDHG/XCTRuntimeAssertions.git", from: "2.2.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.19.2")
    ]
    
    #if canImport(Darwin)
    dependencies += [
        .package(url: "https://github.com/StanfordSpezi/SpeziViews.git", from: "1.12.4"),
        .package(url: "https://github.com/StanfordSpezi/SpeziStorage.git", from: "2.1.4"),
        .package(url: "https://github.com/StanfordSpezi/SpeziNotifications.git", from: "1.0.8"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.4")
    ]
    #endif
    
    return dependencies
}

func targets() -> [Target] { // swiftlint:disable:this function_body_length
    var targets: [Target] = []
    
    var speziSchedulerDependencies: [Target.Dependency] = [
        .product(name: "Spezi", package: "Spezi"),
        .product(name: "SpeziFoundation", package: "SpeziFoundation"),
        .product(name: "Algorithms", package: "swift-algorithms"),
        .product(name: "RuntimeAssertions", package: "XCTRuntimeAssertions")
    ]
    #if canImport(Darwin)
    speziSchedulerDependencies.append(contentsOf: [
        .target(name: "SpeziSchedulerMacros"),
        .product(name: "SpeziViews", package: "SpeziViews"),
        .product(name: "SpeziNotifications", package: "SpeziNotifications"),
        .product(name: "SpeziLocalStorage", package: "SpeziStorage"),
        .product(name: "SQLite", package: "SQLite.swift")
    ])
    #endif
    targets.append(.target(
        name: "SpeziScheduler",
        dependencies: speziSchedulerDependencies,
        swiftSettings: [.enableUpcomingFeature("ExistentialAny")],
        plugins: [] + swiftLintPlugin()
    ))
    
    #if canImport(Darwin)
    targets.append(.macro(
        name: "SpeziSchedulerMacros",
        dependencies: [
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            .product(name: "SwiftDiagnostics", package: "swift-syntax")
        ],
        swiftSettings: [.enableUpcomingFeature("ExistentialAny")],
        plugins: [] + swiftLintPlugin()
    ))
    targets.append(.target(
        name: "SpeziSchedulerUI",
        dependencies: [
            .target(name: "SpeziScheduler"),
            .product(name: "SpeziViews", package: "SpeziViews")
        ],
        resources: [.process("Resources")],
        swiftSettings: [.enableUpcomingFeature("ExistentialAny")],
        plugins: [] + swiftLintPlugin()
    ))
    targets.append(.testTarget(
        name: "SpeziSchedulerTests",
        dependencies: [
            "SpeziScheduler",
            "SpeziSchedulerMacros",
            .product(name: "XCTSpezi", package: "Spezi"),
            .product(name: "SpeziLocalStorage", package: "SpeziStorage"),
            .product(name: "XCTRuntimeAssertions", package: "XCTRuntimeAssertions"),
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
        ],
        resources: [.process("Resources")],
        swiftSettings: [.enableUpcomingFeature("ExistentialAny")],
        plugins: [] + swiftLintPlugin()
    ))
    targets.append(.testTarget(
        name: "SpeziSchedulerUITests",
        dependencies: [
            .target(name: "SpeziScheduler"),
            .target(name: "SpeziSchedulerUI"),
            .product(name: "XCTSpezi", package: "Spezi"),
            .product(name: "SnapshotTesting", package: "swift-snapshot-testing", condition: .when(platforms: [.iOS]))
        ],
        resources: [.process("__Snapshots__")],
        swiftSettings: [.enableUpcomingFeature("ExistentialAny")],
        plugins: [] + swiftLintPlugin()
    ))
//    targets.append(.testTarget(
//        name: "SpeziSchedulerMacrosTest",
//        dependencies: [
//            "SpeziSchedulerMacros",
//            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
//            .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
//        ],
//        swiftSettings: [.enableUpcomingFeature("ExistentialAny")],
//        plugins: [] + swiftLintPlugin()
//    ))
    #endif
    
    return targets
}

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
        [.package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.61.0")]
    } else {
        []
    }
}
