// swift-tools-version:5.7

//
// This source file is part of the CardinalKit open source project
// 
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
// 
// SPDX-License-Identifier: MIT
//

import PackageDescription


let package = Package(
    name: "CardinalKitScheduler",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "CardinalKitScheduler", targets: ["CardinalKitScheduler"])
    ],
    dependencies: [
        .package(url: "https://github.com/StanfordBDHG/CardinalKit", .upToNextMinor(from: "0.4.1"))
    ],
    targets: [
        .target(
            name: "CardinalKitScheduler",
            dependencies: [
                .product(name: "CardinalKit", package: "CardinalKit")
            ]
        ),
        .testTarget(
            name: "CardinalKitSchedulerTests",
            dependencies: [
                .target(name: "CardinalKitScheduler")
            ]
        )
    ]
)
