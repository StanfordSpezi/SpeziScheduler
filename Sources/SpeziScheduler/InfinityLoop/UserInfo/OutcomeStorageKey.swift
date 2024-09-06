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


public protocol OutcomeStorageKey: UserInfoKey where Anchor == OutcomeAnchor {} // TODO: docs
