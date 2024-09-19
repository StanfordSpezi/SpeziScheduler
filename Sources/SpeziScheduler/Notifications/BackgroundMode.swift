//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


@usableFromInline
struct BackgroundMode {
    @usableFromInline static let processing = BackgroundMode(rawValue: "processing")
    @usableFromInline static let fetch = BackgroundMode(rawValue: "fetch")

    @usableFromInline let rawValue: String

    @usableFromInline
    init(rawValue: String) {
        self.rawValue = rawValue
    }
}


extension BackgroundMode: RawRepresentable, Codable, Hashable, Sendable {}
