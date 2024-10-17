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
        let content = UNMutableNotificationContent()
        content.title = String(localized: title, locale: .autoupdatingCurrent)
        content.body = String(localized: instructions)

        if let category {
            content.categoryIdentifier = SchedulerNotifications.notificationCategory(for: category)
        }

        if !schedule.duration.isAllDay {
            content.interruptionLevel = .timeSensitive
        }

        content.sound = .default // will be automatically ignored if sound is not enabled

        content.userInfo[SchedulerNotifications.notificationTaskIdKey] = id

        switch notificationThread {
        case .global:
            content.threadIdentifier = SchedulerNotifications.baseNotificationId
        case .task:
            content.threadIdentifier = SchedulerNotifications.notificationThreadIdentifier(for: id)
        case let .custom(identifier):
            content.threadIdentifier = identifier
        case .none:
            break
        }

        return content
    }
}
