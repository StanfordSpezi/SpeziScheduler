//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


struct BackgroundMode {
    static let processing = BackgroundMode(rawValue: "processing")
    static let fetch = BackgroundMode(rawValue: "fetch")

    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}


extension BackgroundMode: RawRepresentable, Codable, Hashable, Sendable {}
