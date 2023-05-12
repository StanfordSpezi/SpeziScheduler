// swift-tools-version:5.7

//
// This source file is part of the Spezi open source project
// 
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
// 
// SPDX-License-Identifier: MIT
//

import PackageDescription


let package = Package(
    name: "SpeziScheduler",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "SpeziScheduler", targets: ["SpeziScheduler"])
    ],
    dependencies: [
        .package(url: "https://github.com/StanfordSpezi/Spezi", .upToNextMinor(from: "0.5.0"))
    ],
    targets: [
        .target(
            name: "SpeziScheduler",
            dependencies: [
                .product(name: "Spezi", package: "Spezi")
            ]
        ),
        .testTarget(
            name: "SpeziSchedulerTests",
            dependencies: [
                .target(name: "SpeziScheduler")
            ]
        )
    ]
)
