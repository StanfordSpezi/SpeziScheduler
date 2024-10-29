//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Determine the behavior how task notifications are automatically grouped.
public enum NotificationThread {
    /// All task notifications are put into the global SpeziScheduler notification thread.
    case global
    /// The event notification are grouped by task.
    case task
    /// Specify a custom thread identifier.
    case custom(String)
    /// No thread identifier is specified and grouping is done automatically by iOS.
    case none
}


extension NotificationThread: Sendable, Hashable, Codable {}
