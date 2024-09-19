//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI
import UserNotifications


extension UNNotificationTrigger {
    var type: String {
        if self is UNCalendarNotificationTrigger {
            "Calendar"
        } else if self is UNTimeIntervalNotificationTrigger {
            "Interval"
        } else if self is UNLocationNotificationTrigger {
            "Location"
        } else if self is UNPushNotificationTrigger {
            "Push"
        } else {
            "Unknown"
        }
    }

    func nextDate() -> Date? {
        if let calendarTrigger = self as? UNCalendarNotificationTrigger {
            calendarTrigger.nextTriggerDate()
        } else if let intervalTrigger = self as? UNTimeIntervalNotificationTrigger {
            intervalTrigger.nextTriggerDate()
        } else {
            nil
        }
    }
}
