//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import UserNotifications

enum NotificationThread { // TODO: use?
    case scheduler
    case task
    case custom(String)
    case none
}


extension Task {
    /// Determine if any notification-related properties changed that require updating the notifications schedule.
    /// - Parameters:
    ///   - previous: The previous task version.
    ///   - updated: The updated task version.
    /// - Returns: Returns `true` if the notification schedule needs to be updated.
    static func requiresNotificationRescheduling(previous: Task, updated: Task) -> Bool {
        previous.scheduleNotifications != updated.scheduleNotifications
            || previous.schedule.notificationMatchingHint != updated.schedule.notificationMatchingHint
    }


    func notificationContent() -> sending UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: title, locale: .autoupdatingCurrent)
        content.body = String(localized: instructions) // TODO: instructions might be longer! specify notification specific description?

        if let category {
            content.categoryIdentifier = SchedulerNotifications.notificationCategory(for: category)
        }

        if !schedule.duration.isAllDay {
            content.interruptionLevel = .timeSensitive
        }

        content.userInfo[SchedulerNotifications.notificationTaskIdKey] = id

        // TODO: make the grouping "approach" an option? (`notificationThread` global, task, custom).
        content.threadIdentifier = SchedulerNotifications.notificationThreadIdentifier(for: id)

        return content
    }

    @MainActor
    func scheduleNotification(
        notifications: LocalNotifications,
        standard: (any SchedulerNotificationsConstraint)?,
        hint notificationMatchingHint: DateComponents
    ) async throws {
        let content = notificationContent()
        if let standard {
            standard.notificationContent(for: self, content: content)
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: notificationMatchingHint, repeats: true)
        let request = UNNotificationRequest(identifier: SchedulerNotifications.notificationId(for: self), content: content, trigger: trigger)

        try await notifications.add(request: request)
    }
}
