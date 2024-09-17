//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import BackgroundTasks
import Foundation
import Spezi
import SpeziLocalStorage
import SwiftData
import UserNotifications


/// Manage notifications for the Scheduler.
///
/// ## Topics
///
/// ### Configuration
/// - ``init(schedulerLimit:schedulerTimeLimit:)``
/// - ``init()``
///
/// ### Notification Identifier
/// - ``notificationId(for:)``
/// - ``notificationCategory(for:)``
/// - ``notificationThreadIdentifier(for:)``
/// - ``notificationTaskIdKey``
@MainActor
public final class SchedulerNotifications { // TODO: docs!
    @Application(\.logger)
    private var logger

    @Dependency(LocalNotifications.self)
    private var notifications
    @Dependency(LocalStorage.self)
    private var localStorage

    /// The limit of events that should be scheduled at the same time.
    ///
    /// Default is `30`.
    private nonisolated let schedulerLimit: Int
    /// The time period for which we should schedule events.
    ///
    /// Default is `4` weeks.
    private nonisolated let schedulerTimeLimit: TimeInterval

    public required convenience nonisolated init() {
        self.init(schedulerLimit: 30, schedulerTimeLimit: .seconds(1 * 60 * 60 * 24 * 7 * 4))
    }

    public nonisolated init(schedulerLimit: Int, schedulerTimeLimit: Duration) {
        self.schedulerLimit = schedulerLimit
        self.schedulerTimeLimit = Double(schedulerTimeLimit.components.seconds) // TODO: duration doesn't really make things easier!
    }

    @_documentation(visibility: internal)
    public func configure() {
        purgeLegacyEventNotifications()
    }

    func registerProcessingTask(_ action: @escaping (BGAppRefreshTask) -> Void) {
        guard Self.backgroundProcessingEnabled else {
            // TODO: best effort, manualy scheudling uppn app launch! => save date trigger of the background task!
            return // TODO: logger?
        }

        // TODO: returns false if the identifier is not included in the info plist!
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: PermittedBackgroundTaskIdentifier.speziSchedulerNotificationsScheduling.rawValue,
            using: .main
        ) { task in
            guard let backgroundTask = task as? BGAppRefreshTask else {
                return
            }
            MainActor.assumeIsolated {
                action(backgroundTask)
            }
        }
    }

    private func scheduleNotificationsRefresh(nextThreshold: Date? = nil) {
        guard Self.backgroundProcessingEnabled else {
            return
        }

        let now = Date.now
        guard let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: now) else {
            preconditionFailure("Could not calculate next week day for \(now)")
        }

        let earliestBeginDate = if let nextThreshold {
            min(nextWeek, nextThreshold)
        } else {
            nextWeek
        }

        // TODO: does this classify as a processing task?
        let request = BGAppRefreshTaskRequest(identifier: PermittedBackgroundTaskIdentifier.speziSchedulerNotificationsScheduling.rawValue)
        request.earliestBeginDate = earliestBeginDate

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("Failed to schedule notifications processing task for SpeziScheduler: \(error)")
        }
    }
    
    /// Call to handle execution of the background processing task that updates scheduled notifications.
    /// - Parameters:
    ///   - processingTask:
    ///   - scheduler: The scheduler to retrieve the events from.
    func handleNotificationsRefresh(for processingTask: BGAppRefreshTask, using scheduler: Scheduler) {
        let task = _Concurrency.Task { @MainActor in
            do {
                try await updateNotifications(using: scheduler)
                processingTask.setTaskCompleted(success: true)
            } catch {
                logger.error("Failed to update notifications: \(error)")
                processingTask.setTaskCompleted(success: false)
            }
        }

        processingTask.expirationHandler = {
            task.cancel()
        }
    }

    // TODO: we need an async semaphore to make sure we do not get a race condition here!
    func taskLevelScheduling(using scheduler: Scheduler) async throws {
        let now = Date.now
        let tasks = try scheduler
            .queryTasks(for: now..., predicate: #Predicate { task in
                task.scheduleNotifications
            })
            .filter { task in
                // TODO: can we make that part of the query?
                task.schedule.canBeScheduledAsCalendarTrigger()
            }

        let pendingCalendarNotifications = await notifications.pendingNotificationRequests()
            .filter { request in
                request.identifier.starts(with: Self.baseNotificationId)
                    && request.trigger is UNCalendarNotificationTrigger
            }
            .reduce(into: [:]) { partialResult, request in
                partialResult[request.identifier] = request
            }

        // TODO: do this for the events-based notifications as well!
        let removedNotifications = Set(pendingCalendarNotifications.keys).subtracting(tasks.map { $0.id })
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Array(removedNotifications))

        // TODO: cancel event-based notifications of the task!


        for task in tasks {
            try _Concurrency.Task.checkCancellation() // TODO: affects setting the completion of the BG task!

            lazy var content = task.notificationContent()

            if let existingRequest = pendingCalendarNotifications[SchedulerNotifications.notificationId(for: task)] {
                if existingRequest.content == content { // TODO: might anything else change except the content?
                    continue // notification is the same
                } else {
                    // notification exists, but is outdated, so remove it and redo it
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [existingRequest.identifier])
                }
            }

            // checked above already
            guard let notificationMatchingHint = task.schedule.notificationMatchingHint else {
                continue
            }


            do {
                try await measure(name: "Task Notification Request") {
                    try await task.scheduleNotification(notifications: notifications, hint: notificationMatchingHint)
                }
            } catch {
                // TODO: anything we can do?
                logger.error("Failed to register remote notification for task \(task.id) for hint \(notificationMatchingHint)")
            }
        }
        // TODO: when do we need to re-schedule (first task that ends?)
        // TODO: check if it is not indefinitly => check if the last event is part of next week?
    }

    // TODO: when to call?
    func updateNotifications(using scheduler: Scheduler) async throws {
        // TODO: move first few lines to the scheduler, just pass in list of events that should be scheduled!

        /*
         We can only schedule a limited amount of notifications at the same time.
         Therefore, we do the following:
         1) Just consider the events within the `schedulerTimeLimit`.
         2) Sort all events by their occurrence.
         3) Take the first N events and schedule their notifications, with N=`schedulerLimit`.
         */
        // TODO: this might schedule way less notifications if there are only few notifications in the 4 weeks => this is okay!

        // TODO: on this level we cannot reason about task level scheduling (e.g., where we have a notifications shorthand via timer interval!).
        //  => have a separate query that only looks at tasks who's schedule can be represented using DateComponents and who's start date allows
        //  => for that => would need to set queryable attributes!

        let now: Date = .now

        guard try scheduler.hasTasksWithNotifications(for: now...) else {
            // TODO: we might have added a new task versions with notifications disabled.
            //  => we need to make sure we to cancel upcoming occurrences!
            return
        }

        // We query all future events until next month. We receive the result sorted.
        // We don't query the outcomes at all. So all events will seem like they are not completed.
        let events = try scheduler.queryEventsWithoutOutcomes(for: now..<now.addingTimeInterval(schedulerTimeLimit), predicate: #Predicate { task in
            task.scheduleNotifications == true
        })
            .prefix(schedulerLimit) // limit to the maximum amount of notifications we can schedule

        guard let firstEvent = events.first else {
            // no new tasks in our query window, schedule a background task next week
            scheduleNotificationsRefresh() // TODO: repetitive and error prone!
            return // no tasks with enabled notifications!
        }

        // TODO: support .deliveredNotifications() + pendingNotificationRequests with sending return types

        let pendingNotifications = await notifications.pendingNotificationRequests().filter { request in
            request.identifier.starts(with: Self.baseNotificationId)
        }
        let pendingNotificationIdentifiers = Set(pendingNotifications.map { $0.identifier })

        let remainingLimit = await self.notifications.remainingNotificationLimit()


        // TODO: move up, if this is zero, we could just stop and assume notifications are fine? However, just a count assumption then :/
        let remainingSpace = remainingLimit - pendingNotifications.count // TODO: we might generally not have enough space for stuff!
        // TODO: let ourOwnReamingLimit = schedulerLimit - pendingNotifications.count

        let schedulingEvents = events.prefix(remainingSpace) // TODO: do only one prefix?

        guard let lastScheduledEvent = schedulingEvents.last else {
            // currently no space left to schedule notifications. make sure to schedule background task before the next event.
            let nextTimeInterval = firstEvent.occurrence.start.timeIntervalSinceNow * 0.75 // TODO: set factor via variable!
            scheduleNotificationsRefresh(nextThreshold: Date.now.addingTimeInterval(nextTimeInterval))
            return // nothing got scheduled!
        }

        // TODO: mark this as something that can continue in the background!
        for event in schedulingEvents {
            try _Concurrency.Task.checkCancellation() // TODO: affects setting the completion of the BG task!

            // TODO: we might have notifications that got removed! (due to task changes (new task versions))
            //  => make sure that we also do the reverse check of, which events are not present anymore?
            //  => need information that pending notifications are part of our schedule? just cancel anything more in the future?
            guard !pendingNotificationIdentifiers.contains(SchedulerNotifications.notificationId(for: event)) else {
                // TODO: improve how we match existing notifications
                continue // TODO: if we allow to customize, we might need to check if the notification changed?
            }

            // TODO: support task cancellation!

            do {
                try await measure(name: "Event Notification Request") {
                    try await event.scheduleNotification(notifications: notifications)
                }
            } catch {
                // TODO: anything we can do?
                logger.error("Failed to register remote notification for task \(event.task.id) for date \(event.occurrence.start)")
            }
        }

        // TODO: check if are more events coming?
        // TODO: max one week!
        let nextTimeInterval = lastScheduledEvent.occurrence.start.timeIntervalSinceNow * 0.75
        scheduleNotificationsRefresh(nextThreshold: Date.now.addingTimeInterval(nextTimeInterval))
    }
}


extension SchedulerNotifications: Module, DefaultInitializable {}


extension SchedulerNotifications {
    static var uiBackgroundModes: Set<BackgroundMode> {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        return modes.map { modes in
            modes.reduce(into: Set()) { partialResult, rawValue in
                partialResult.insert(BackgroundMode(rawValue: rawValue))
            }
        } ?? []
    }

    static var permittedBackgroundTaskIdentifiers: Set<PermittedBackgroundTaskIdentifier> {
        let identifiers = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String]
        return identifiers.map { identifiers in
            identifiers.reduce(into: Set()) { partialResult, rawValue in
                partialResult.insert(PermittedBackgroundTaskIdentifier(rawValue: rawValue))
            }
        } ?? []
    }

    static var backgroundProcessingEnabled: Bool {
        // TODO: warning!
        uiBackgroundModes.contains(.processing) && permittedBackgroundTaskIdentifiers.contains(.speziSchedulerNotificationsScheduling)
    }
}


extension SchedulerNotifications {
    /// Access the task id from the `userInfo` of a notification.
    ///
    /// The ``Task/id`` is stored in the [`userInfo`](https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent/userinfo)
    /// property of a notification. This string identifier is used as the key.
    ///
    /// ```swift
    /// let content = content.userInfo[SchedulerNotifications.notificationTaskIdKey]
    /// ```
    public static nonisolated var notificationTaskIdKey: String {
        "\(baseNotificationId).taskId"
    }

    static nonisolated var baseNotificationId: String {
        "edu.stanford.spezi.scheduler.notification"
    }

    /// Retrieve the category identifier for a notification for a task, derived from its task category.
    ///
    /// This method derive the notification category from the task category. If a task has a task category set, it will be used to set the
    /// [`categoryIdentifier`](https://developer.apple.com/documentation/usernotifications/unnotificationcontent/categoryidentifier) of the
    /// notification content.
    /// By matching against the notification category, you can [Customize the Appearance of Notifications](https://developer.apple.com/documentation/usernotificationsui/customizing-the-appearance-of-notifications)
    /// or [Handle user-selected actions](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions#Handle-user-selected-actions).
    ///
    /// - Parameter category: The task category to generate the category identifier for.
    /// - Returns: The category identifier supplied in the notification content.
    public static nonisolated func notificationCategory(for category: Task.Category) -> String {
        "\(baseNotificationId).category.\(category.rawValue)"
    }
    
    /// The notification thread identifier for a given task.
    ///
    /// If notifications are grouped by task, this method can be used to derive the thread identifier from the task ``Task/id``.
    /// - Parameter taskId: The task identifier.
    /// - Returns: The notification thread identifier for a task.
    public static nonisolated func notificationThreadIdentifier(for taskId: String) -> String {
        "\(notificationTaskIdKey).\(taskId)"
    }
    
    /// The notification request identifier for a given event.
    /// - Parameter event: The event.
    /// - Returns: Returns the identifier for the notification request when sending a request for the specified event.
    public static nonisolated func notificationId(for event: Event) -> String {
        "\(baseNotificationId).event.\(event.occurrence.start)" // TODO: brint timeInterval since Reference?
    }

    public static nonisolated func notificationId(for task: Task) -> String {
        "\(baseNotificationId).task.\(task.id)"
    }
}


extension SchedulerNotifications {
    /// Cancel scheduled and delivered notifications of the legacy SpeziScheduler 1.0
    fileprivate func purgeLegacyEventNotifications() {
        let legacyStorageKey = "spezi.scheduler.tasks" //t he legacy scheduler 1.0 used to store tasks at this location.

        let legacyTasks: [LegacyTaskModel]
        do {
            legacyTasks = try localStorage.read(storageKey: legacyStorageKey)
        } catch {
            let nsError = error as NSError
            if nsError.domain == CocoaError.errorDomain
                && (nsError.code == CocoaError.fileReadNoSuchFile.rawValue || nsError.code == CocoaError.fileNoSuchFile.rawValue ) {
                return
            }
            logger.warning("Failed to read legacy task storage entries: \(error)")
            return
        }

        for task in legacyTasks {
            for event in task.events {
                event.cancelNotification()
            }
        }

        // We don't support migration, so just remove it.
        do {
            try localStorage.delete(storageKey: legacyStorageKey)
        } catch {
            logger.warning("Failed to remove legacy scheduler task storage: \(error)")
        }
    }
}
