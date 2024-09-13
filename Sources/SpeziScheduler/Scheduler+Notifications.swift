//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SwiftData
@preconcurrency import UserNotifications


extension Scheduler {
    private var schedulerLimit: Int {
        30
        // TODO: additional time limit (30 or 1 month in advance?) and then background tasks?
    }

    private var schedulerTimeLimit: TimeInterval {
        // default limit is 4 weeks
        1 * 60 * 60 * 24 * 7 * 4
    }
    // TODO: cancel all legacy notifications!

    func updateNotifications() async throws {
        // TODO: this might qualify as a processing task?
        // TODO: add background fetch task (if enabled) to reschedule every week?
        // TODO: then reschedule in the background on the 75% of the latest scheduled event! (but max a week?)

        /*
         We can only schedule a limited amount of notifications at the same time.
         Therefore, we do the following:
         1) Just consider the events within the `schedulerTimeLimit`.
         2) Sort all events by their occurrence.
         3) Take the first N events and schedule their notifications, with N=`schedulerLimit`.
         */
        // TODO: this might schedule way less notifications if there are only few notifications in the 4 weeks
        // TODO: on this level we cannot reason about task level scheduling (e.g., where we have a notifications shorthand via timer interval!).
        //  => have a separate query that only looks at tasks who's schedule can be represented using DateComponents and who's start date allows
        //  => for that => would need to set queryable attributes!

        let now: Date = .now
        let range = now..<now.addingTimeInterval(schedulerTimeLimit)

        // TODO: allow to skip querying the outcomes for more efficiency!
        // we query all future events until next month. We receive the result sorted
        let events = try queryEvents(for: range, predicate: #Predicate { task in
            task.scheduleNotifications == true
        })
            .prefix(schedulerLimit) // limit to the maximum amount of notifications we can schedule
        // TODO: are we able to batch that?

        guard !events.isEmpty else {
            return // no tasks with enabled notifications!
        }

        // TODO: support .deliveredNotifications() + pendingNotificationRequests with sending return types

        let pendingNotifications = Set(await UNUserNotificationCenter.current()
            .pendingNotificationRequests()
            .map { $0.identifier }
            .filter { $0.starts(with: "edu.stanford.spezi.scheduler." ) })
        // TODO: existing notifications

        let remainingLimit = await self.notifications.remainingNotificationLimit()


        // TODO: move up, if this is zero, we could just stop and assume notifications are fine? However, just a count assumption then :/
        let remainingSpace = remainingLimit - pendingNotifications.count // TODO: we might generally not have enough space for stuff!
        // TODO: let ourOwnReamingLimit = schedulerLimit - pendingNotifications.count

        let schedulingEvents = events.prefix(remainingSpace) // TODO: do only one prefix?

        guard let lastScheduledEvent = schedulingEvents.last else {
            return // nothing got scheduled!
        }

        for event in schedulingEvents {
            // TODO: we might have notifications that got removed! (due to task changes (new task versions))
            //  => make sure that we also do the reverse check of, which events are not present anymore?
            //  => need information that pending notifications are part of our schedule? just cancel anything more in the future?
            guard !pendingNotifications.contains(event.notificationId) else {
                // TODO: improve how we match existing notifications
                continue // TODO: if we allow to customize, we might need to check if the notification changed?
            }

            do {
                try await measure(name: "Notification Request") {
                    try await event.scheduleNotification(notifications: notifications)
                }
            } catch {
                // TODO: anything we can do?
                logger.error("Failed to register remote notification for task \(event.task.id) for date \(event.occurrence.start)")
            }
        }
    }
}


// TODO: eventually move somewhere else!
extension Event {
    var notificationId: String {
        "edu.stanford.spezi.scheduler.\(occurrence.start)"
    }

    fileprivate func scheduleNotification(
        isolation: isolated (any Actor)? = #isolation,
        notifications: LocalNotifications
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = String(localized: task.title) // TODO: check, localization might change!
        // TODO: there is otherwise localizedUserNotificationString(forKey:arguments:)
        content.body = String(localized: task.instructions) // TODO: instructions might be longer! specify custom?

        let interval = task.schedule.start.timeIntervalSince(.now)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)

        try await notifications.add(request: request)
    }
}
