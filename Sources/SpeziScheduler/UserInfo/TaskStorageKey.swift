//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziFoundation


/// Storage anchor for the additional storage of a task.
@_documentation(visibility: internal)
public enum TaskAnchor: RepositoryAnchor {}


/// Store additional information in a `Task`.
///
/// Using a `TaskStorageKey` you can store additional data in a ``Task``.
///
/// For more information, refer to the documentation of the ``Property()`` macro.
@_documentation(visibility: internal)
public protocol TaskStorageKey: _UserInfoKey where Anchor == TaskAnchor, Value: Equatable {}
