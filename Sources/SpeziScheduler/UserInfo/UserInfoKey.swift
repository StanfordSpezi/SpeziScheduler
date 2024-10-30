//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation


/// A typed-key for entries in the user info store of scheduler components.
///
/// Refer to the documentation of ``TaskStorageKey`` and ``OutcomeStorageKey`` on how to create userInfo entries.
public protocol _UserInfoKey<Anchor>: KnowledgeSource where Value: Codable { // swiftlint:disable:this type_name
    associatedtype Encoder: TopLevelEncoder, Sendable where Encoder.Output == Data
    associatedtype Decoder: TopLevelDecoder, Sendable where Decoder.Input == Data

    /// The persistent identifier of the user info key.
    static var identifier: String { get }
    /// The encoder and decoder used with the user storage.
    static var coding: UserStorageCoding<Encoder, Decoder> { get }
}


extension _UserInfoKey {
    /// Default identifier corresponding to the type name.
    public static var identifier: String {
        "\(Self.self)"
    }
}
