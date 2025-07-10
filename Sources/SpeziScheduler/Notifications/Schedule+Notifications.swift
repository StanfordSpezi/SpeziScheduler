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
    enum NotificationMatchingHint: Codable, Sendable, Hashable {
        case none
        case components(hour: Int?, minute: Int, second: Int, weekday: Int?)
        case allDayNotification(weekday: Int?)
        
        func dateComponents(calendar: Calendar, allDayNotificationTime: NotificationTime) -> DateComponents? {
            switch self {
            case .none:
                return nil
            case let .components(hour, minute, second, weekday):
                return DateComponents(calendar: calendar, hour: hour, minute: minute, second: second, weekday: weekday)
            case let .allDayNotification(weekday):
                let time = allDayNotificationTime
                return DateComponents(calendar: calendar, hour: time.hour, minute: time.minute, second: time.second, weekday: weekday)
            }
        }
    }
    
    
    static func notificationTime(for start: Date, duration: Duration, allDayNotificationTime: NotificationTime) -> Date {
        if duration.isAllDay {
            let time = allDayNotificationTime
            guard let morning = Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: time.second, of: start) else {
                preconditionFailure("Failed to set hour of start date \(start)")
            }
            return morning
        } else {
            return start
        }
    }
    
    
    static func notificationMatchingHint( // swiftlint:disable:this function_parameter_count
        forMatchingInterval interval: Int,
        calendar: Calendar,
        hour: Int?,
        minute: Int,
        second: Int,
        weekday: Int? = nil, // swiftlint:disable:this function_default_parameter_at_end
        consider duration: Duration
    ) -> NotificationMatchingHint {
        guard interval == 1 else {
            return .none
        }
        if duration.isAllDay {
            return .allDayNotification(weekday: weekday)
        } else {
            return .components(hour: hour, minute: minute, second: second, weekday: weekday)
        }
    }

    func canBeScheduledAsRepeatingCalendarTrigger(allDayNotificationTime: NotificationTime, now: Date = .now) -> Bool {
        guard notificationMatchingHint != .none, let recurrence else {
            return false // needs to be repetitive and have a interval hint
        }

        if now > start {
            return true // if we are past the start date, it is definitely possible
        }

        // otherwise, check if it still works (e.g., we have Monday, start date is Wednesday and schedule reoccurs every Friday).
        guard let components = notificationMatchingHint.dateComponents(
            calendar: recurrence.calendar,
            allDayNotificationTime: allDayNotificationTime
        ) else {
            return false
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        guard let nextDate = trigger.nextTriggerDate() else {
            return false
        }

        let nextOccurrences = nextOccurrences(in: now..., count: 2)
        guard let nextOccurrence = nextOccurrences.first,
              nextOccurrences.count >= 2 else {
            // we require at least two next occurrences to justify a **repeating** calendar-based trigger
            return false
        }

        if duration.isAllDay {
            // we deliver notifications for all day occurrences at a different time

            let time = allDayNotificationTime
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
