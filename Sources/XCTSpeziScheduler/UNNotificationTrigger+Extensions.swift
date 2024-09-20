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
    var type: LocalizedStringResource {
        if self is UNCalendarNotificationTrigger {
            LocalizedStringResource("Calendar", bundle: .atURL(from: .module))
        } else if self is UNTimeIntervalNotificationTrigger {
            LocalizedStringResource("Interval", bundle: .atURL(from: .module))
        } else if self is UNPushNotificationTrigger {
            LocalizedStringResource("Push", bundle: .atURL(from: .module))
        } else {
#if !os(visionOS) && !os(macOS)
            if self is UNLocationNotificationTrigger {
                LocalizedStringResource("Location", bundle: .atURL(from: .module))
            } else {
                LocalizedStringResource("Unknown", bundle: .atURL(from: .module))
            }
#else
            LocalizedStringResource("Unknown", bundle: .atURL(from: .module))
#endif
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
