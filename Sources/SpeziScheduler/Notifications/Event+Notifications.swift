//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import UserNotifications


extension Event {
    func scheduleNotification( // swiftlint:disable:this function_default_parameter_at_end
        isolation: isolated (any Actor)? = #isolation,
        notifications: LocalNotifications,
        allDayNotificationTime: NotificationTime
    ) async throws {
        let content = task.notificationContent()

        let notificationTime = Schedule.notificationTime(
            for: occurrence.start,
            duration: occurrence.schedule.duration,
            allDayNotificationTime: allDayNotificationTime
        )
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: notificationTime.timeIntervalSinceNow, repeats: false)

        let request = UNNotificationRequest(identifier: SchedulerNotifications.notificationId(for: self), content: content, trigger: trigger)

        try await notifications.add(request: request)
    }
}
