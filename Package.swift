// swift-tools-version:5.9

//
// This source file is part of the Stanford Spezi open-source project
// 
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
// 
// SPDX-License-Identifier: MIT
//

import PackageDescription


let package = Package(
    name: "SpeziScheduler",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "SpeziScheduler", targets: ["SpeziScheduler"])
    ],
    dependencies: [
        .package(url: "https://github.com/StanfordSpezi/Spezi", from: "1.2.3"),
        .package(url: "https://github.com/StanfordSpezi/SpeziStorage", from: "1.0.2")
    ],
    targets: [
        .target(
            name: "SpeziScheduler",
            dependencies: [
                .product(name: "Spezi", package: "Spezi"),
                .product(name: "SpeziLocalStorage", package: "SpeziStorage")
            ]
        ),
        .testTarget(
            name: "SpeziSchedulerTests",
            dependencies: [
                .target(name: "SpeziScheduler"),
                .product(name: "XCTSpezi", package: "Spezi"),
                .product(name: "SpeziLocalStorage", package: "SpeziStorage")
            ]
        )
    ]
)
