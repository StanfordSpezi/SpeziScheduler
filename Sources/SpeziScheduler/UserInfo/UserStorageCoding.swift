//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation


/// Defining the coding strategy for a user storage property.
///
/// This type defines the encoders and decoders for a user storage ``Property(coding:)``.
///
/// Below is a code example that specifies ``json`` encoding for the `measurementType` property.
///
/// ```swift
/// extension Task.Context {
///     @Property(coding: .json)
///     var measurementType: MeasurementType?
/// }
/// ```
///
/// ## Topics
///
/// ### Builtin Strategies
/// - ``json``
/// - ``propertyList``
///
/// ### Custom Strategies
/// - ``custom(encoder:decoder:)``
public struct UserStorageCoding<Encoder: TopLevelEncoder & Sendable, Decoder: TopLevelDecoder & Sendable>: Sendable
    where Encoder.Output == Data, Decoder.Input == Data {
    let encoder: Encoder
    let decoder: Decoder
    
    init(encoder: Encoder, decoder: Decoder) {
        self.encoder = encoder
        self.decoder = decoder
    }
    
    /// Create a custom user storage coding strategy.
    /// - Parameters:
    ///   - encoder: The encoder.
    ///   - decoder: The decoder.
    /// - Returns: The coding strategy.
    public static func custom(encoder: Encoder, decoder: Decoder) -> UserStorageCoding<Encoder, Decoder> {
        .init(encoder: encoder, decoder: decoder)
    }
}


extension UserStorageCoding where Encoder == JSONEncoder, Decoder == JSONDecoder {
    /// JSON encoder and decoder.
    public static let json = UserStorageCoding(
        encoder: { () -> JSONEncoder in
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            return encoder
        }(),
        decoder: JSONDecoder()
    )
}


extension UserStorageCoding where Encoder == PropertyListEncoder, Decoder == PropertyListDecoder {
    /// PropertyList encoder and decoder.
    public static let propertyList = UserStorageCoding(encoder: PropertyListEncoder(), decoder: PropertyListDecoder())
}
