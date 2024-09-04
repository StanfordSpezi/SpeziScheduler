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


public protocol TaskStorageKey: UserInfoKey where Anchor == TaskAnchor, Value: Equatable {} // TODO: Docs
