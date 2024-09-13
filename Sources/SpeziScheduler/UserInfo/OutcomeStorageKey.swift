//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziFoundation


/// The storage anchor for additional user info storage entries for an `Outcome`.
@_documentation(visibility: internal)
public enum OutcomeAnchor: RepositoryAnchor {}


/// Store additional information in an `Outcome`.
///
/// Using a `OutcomeStorageKey` you can store additional data in an ``Outcome``.
///
/// For more information, refer to the documentation of the ``Property()`` macro.
@_documentation(visibility: internal)
public protocol OutcomeStorageKey: _UserInfoKey where Anchor == OutcomeAnchor {}
