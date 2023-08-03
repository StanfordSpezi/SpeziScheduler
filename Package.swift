// swift-tools-version:5.7

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
        .iOS(.v16)
    ],
    products: [
        .library(name: "SpeziScheduler", targets: ["SpeziScheduler"])
    ],
    dependencies: [
        .package(url: "https://github.com/StanfordSpezi/Spezi", .upToNextMinor(from: "0.7.0")),
        .package(url: "https://github.com/StanfordSpezi/SpeziStorage", .upToNextMinor(from: "0.4.1"))
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
                .product(name: "SpeziLocalStorage", package: "SpeziStorage")
            ]
        )
    ]
)
