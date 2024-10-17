//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Hour, minute and second date components to determine the scheduled time of a notification.
public struct NotificationTime {
    /// The hour component.
    public let hour: Int
    /// The minute component.
    public let minute: Int
    /// The second component
    public let second: Int

    
    /// Create a new notification time.
    /// - Parameters:
    ///   - hour: The hour component.
    ///   - minute: The minute component.
    ///   - second: The second component
    public init(hour: Int, minute: Int = 0, second: Int = 0) {
        self.hour = hour
        self.minute = minute
        self.second = second

        precondition((0..<24).contains(hour), "hour must be between 0 and 23")
        precondition((0..<60).contains(minute), "minute must be between 0 and 59")
        precondition((0..<60).contains(second), "second must be between 0 and 59")
    }
}


extension NotificationTime: Sendable, Codable, Hashable {}
