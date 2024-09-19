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
    @MainActor
    func scheduleNotification(
        notifications: LocalNotifications,
        standard: (any SchedulerNotificationsConstraint)?,
        allDayNotificationTime: NotificationTime
    ) async throws {
        let content = task.notificationContent()
        if let standard {
            standard.notificationContent(for: task, content: content)
        }

        let notificationTime = Schedule.notificationTime(
            for: occurrence.start,
            duration: occurrence.schedule.duration,
            allDayNotificationTime: allDayNotificationTime
        )
        print("Scheduling event notification in \(notificationTime.timeIntervalSinceNow)") // TODO: remove
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: notificationTime.timeIntervalSinceNow, repeats: false)

        let request = UNNotificationRequest(identifier: SchedulerNotifications.notificationId(for: self), content: content, trigger: trigger)

        try await notifications.add(request: request)
    }
}
