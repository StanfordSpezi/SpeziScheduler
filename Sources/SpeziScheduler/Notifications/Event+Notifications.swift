//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
@preconcurrency import UserNotifications


// TODO: eventually move somewhere else!
extension Event {
    func scheduleNotification( // swiftlint:disable:this function_default_parameter_at_end
        isolation: isolated (any Actor)? = #isolation,
        notifications: LocalNotifications
    ) async throws {
        let isAllDay = occurrence.schedule.duration.isAllDay

        let content = UNMutableNotificationContent()
        content.title = String(localized: task.title) // TODO: check, localization might change!
        // TODO: there is otherwise localizedUserNotificationString(forKey:arguments:)
        content.body = String(localized: task.instructions)
        // TODO: instructions might be longer! specify notification specific description?

        // TODO: support: subtitle, sound, attachments??, userInfo?, relevanceScore, filterCriteria (focus)
        // TODO: targetContentIdentifier (which application window to bring forward)

        if let category = task.category {
            // TODO: allow to derive the category easily (adding custom actions is possible!!) => providing custom notifications UI!
            content.categoryIdentifier = SchedulerNotifications.notificationCategory(for: category)
        }

        if !isAllDay {
            content.interruptionLevel = .timeSensitive // TODO: document required entitlement!
        }

        content.userInfo[SchedulerNotifications.notificationTaskIdKey] = task.id

        // TODO: make the grouping "approach" an option? (`notificationThread` global, task, custom).
        content.threadIdentifier = SchedulerNotifications.notificationThreadIdentifier(for: task.id)

        let start: Date
        if isAllDay {
            // default to 9am // TODO: customize that?
            guard let morning = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: occurrence.start) else {
                preconditionFailure("Failed to set hour of start date \(occurrence.start)")
            }
            start = morning
        } else {
            start = occurrence.start
        }


        // TODO: or what is generally a good way to customize the notification


        let interval = start.timeIntervalSince(.now)

        // TODO: set a different trigger for all day notifications (9 am?)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        let request = UNNotificationRequest(identifier: SchedulerNotifications.notificationId(for: self), content: content, trigger: trigger)

        try await notifications.add(request: request)
    }
}
