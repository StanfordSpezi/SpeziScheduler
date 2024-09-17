//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import UserNotifications


extension Schedule {
    static var defaultNotificationTime: (hour: Int, minute: Int, second: Int) {
        // default to 9am // TODO: customize that?
        (9, 0, 0)
    }

    static func notificationTime(for start: Date, duration: Duration) -> Date {
        if duration.isAllDay {
            let time = defaultNotificationTime
            guard let morning = Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: time.second, of: start) else {
                preconditionFailure("Failed to set hour of start date \(start)")
            }
            return morning
        } else {
            return start
        }
    }

    static func notificationIntervalHint(
        forMatchingInterval interval: Int,
        calendar: Calendar,
        hour: Int,
        minute: Int,
        second: Int,
        weekday: Int? = nil,
        consider duration: Duration
    ) -> DateComponents? {
        guard interval == 1 else {
            return nil
        }

        if duration.isAllDay {
            let time = defaultNotificationTime
            return DateComponents(calendar: calendar, hour: time.hour, minute: time.minute, second: time.second, weekday: weekday)
        } else {
            return DateComponents(calendar: calendar, hour: hour, minute: minute, second: second, weekday: weekday)
        }
    }

    func canBeScheduledAsCalendarTrigger(now: Date = .now) -> Bool {
        guard let notificationMatchingHint, recurrence != nil else {
            return false // needs to be repetitive and have a interval hint
        }

        if now > start {
            return true // if we are past the start date, it is definitely possible
        }

        // otherwise, check if it still works (e.g., we have Monday, start date is Wednesday and schedule reoccurs every Friday).
        let trigger = UNCalendarNotificationTrigger(dateMatching: notificationMatchingHint, repeats: true)
        guard let nextDate = trigger.nextTriggerDate() else {
            return false
        }

        guard let nextOccurrence = nextOccurrence(from: now) else {
            return false
        }

        if duration.isAllDay {
            // we deliver notifications for all day occurrences at a different time

            let time = Self.defaultNotificationTime
            guard let modifiedOccurrence = Calendar.current.date(
                bySettingHour: time.hour,
                minute: time.minute,
                second: time.second,
                of: nextOccurrence.start
            ) else {
                preconditionFailure("Failed to set notification time for date \(nextOccurrence.start)")
            }

            return nextDate == modifiedOccurrence
        } else {
            return nextDate == nextOccurrence.start
        }
    }
}
