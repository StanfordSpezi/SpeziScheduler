//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import UserNotifications


/// Customize the notification content of SpeziScheduler notifications.
///
/// Below is an implementation that adds a subtitle to every notification.
/// ```swift
/// actor MyActor: Standard, SchedulerNotificationsConstraint {
///     @MainActor
///     func updateNotificationContent(for event: borrowing Event, content: borrowing UNMutableNotificationContent) {
///         content.subtitle = "Complete the Questionnaire"
///     }
/// }
/// ```
public protocol SchedulerNotificationsConstraint: Standard {
    /// Customize the notification content of a notification for the event of a task.
    /// - Parameters:
    ///   - task: The ``Event`` for which we generate the notification for.
    ///   - content: The default notification content generated by ``SchedulerNotifications`` that can be customized.
    @MainActor
    func updateNotificationContent(for event: borrowing Event, content: borrowing UNMutableNotificationContent)
    
    
    @available(*, deprecated, renamed: "updateNotificationContent(for:content:)")
    @MainActor
    func notificationContent(for event: borrowing Task, content: borrowing UNMutableNotificationContent)
}


extension SchedulerNotificationsConstraint {
    @MainActor
    func updateNotificationContent(for event: borrowing Event, content: borrowing UNMutableNotificationContent) {
        notificationContent(for: event.task, content: content)
    }
    
    @MainActor
    func notificationContent(for event: borrowing Task, content: borrowing UNMutableNotificationContent) {}
}
