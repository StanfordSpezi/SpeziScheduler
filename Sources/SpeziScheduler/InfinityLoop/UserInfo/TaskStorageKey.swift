//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziFoundation


/// Storage anchor for the additional storage of a task.
public enum TaskAnchor: RepositoryAnchor {}


/// Store additional information in a `Task`.
///
/// Using a `TaskStorageKey` you can store additional data in a ``ILTask``.
///
/// You can store any `Codable` value in Task by adding a new entry using the ``UserStorageEntry()`` macro.
/// Just extend ``ILTask/Context`` by adding a new property with optional type.
/// ```swift
/// extension ILTask.Context {
///     @UserInfoEntry var measurementType: MeasurementType?
/// }
/// ```
public protocol TaskStorageKey: _UserInfoKey where Anchor == TaskAnchor, Value: Equatable {}
