//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import UserNotifications


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
        // TODO: or what is generally a good way to customize the notification

        
        let content = UNMutableNotificationContent()
        // TODO: do we need to update the localized string? (otherwise localizedUserNotificationString(forKey:arguments:)?)
        content.title = String(localized: title, locale: .autoupdatingCurrent)
        content.body = String(localized: instructions) // TODO: instructions might be longer! specify notification specific description?

        // TODO: support: subtitle, sound, attachments??, userInfo?, relevanceScore, filterCriteria (focus)
        // TODO: targetContentIdentifier (which application window to bring forward)

        if let category {
            content.categoryIdentifier = SchedulerNotifications.notificationCategory(for: category)
        }

        if !schedule.duration.isAllDay {
            content.interruptionLevel = .timeSensitive // TODO: document required entitlement!
        }

        content.userInfo[SchedulerNotifications.notificationTaskIdKey] = id

        // TODO: make the grouping "approach" an option? (`notificationThread` global, task, custom).
        content.threadIdentifier = SchedulerNotifications.notificationThreadIdentifier(for: id)

        return content
    }

    func scheduleNotification( // swiftlint:disable:this function_default_parameter_at_end
        isolation: isolated (any Actor)? = #isolation,
        notifications: LocalNotifications,
        hint notificationMatchingHint: DateComponents
    ) async throws {
        let content = notificationContent()
        let trigger = UNCalendarNotificationTrigger(dateMatching: notificationMatchingHint, repeats: true)
        let request = UNNotificationRequest(identifier: SchedulerNotifications.notificationId(for: self), content: content, trigger: trigger)

        try await notifications.add(request: request) // TODO: parameter doesn't need to be sending?
    }
}
