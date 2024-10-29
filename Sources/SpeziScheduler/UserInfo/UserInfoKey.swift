//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziFoundation


/// A typed-key for entries in the user info store of scheduler components.
///
/// Refer to the documentation of ``TaskStorageKey`` and ``OutcomeStorageKey`` on how to create userInfo entries.
public protocol _UserInfoKey<Anchor>: KnowledgeSource where Value: Codable { // swiftlint:disable:this type_name
    /// The persistent identifier of the user info key.
    static var identifier: String { get }
}


extension _UserInfoKey {
    /// Default identifier corresponding to the type name.
    public static var identifier: String {
        "\(Self.self)"
    }
}
