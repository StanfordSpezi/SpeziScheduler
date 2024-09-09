//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziFoundation


/// The storage anchor for additional user info storage entries for an `Outcome`.
public enum OutcomeAnchor: RepositoryAnchor {}


/// Store additional information in an `Outcome`.
///
/// Using a `OutcomeStorageKey` you can store additional data in an ``Outcome``.
///
/// You can store any `Codable` value in an Outcome by adding a new entry using the ``UserStorageEntry()`` macro.
/// Just extend `Outcome` by adding a new property with optional type.
/// ```swift
/// extension Outcome {
///     @UserInfoEntry var tag: String?
/// }
/// ```
public protocol OutcomeStorageKey: _UserInfoKey where Anchor == OutcomeAnchor {}
