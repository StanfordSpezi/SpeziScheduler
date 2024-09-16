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
@preconcurrency import UserNotifications


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

    func registerProcessingTask(_ action: @escaping (BGProcessingTask) -> Void) {
        guard Self.backgroundProcessingEnabled else {
            return // TODO: logger?
        }

        // TODO: returns false if the identifier is not included in the info plist!
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: PermittedBackgroundTaskIdentifier.speziSchedulerNotificationsScheduling.rawValue,
            using: .main
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                return
            }
            MainActor.assumeIsolated {
                action(processingTask)
            }
        }
    }

    private func scheduleNotificationsRefresh(nextThreshold: Date? = nil) {
        guard Self.backgroundProcessingEnabled else {
            return
        }

        // TODO: really a processing task? we restrict ourselves to power reserve modes?
        let request = BGProcessingTaskRequest(identifier: PermittedBackgroundTaskIdentifier.speziSchedulerNotificationsScheduling.rawValue)
        request.earliestBeginDate = nextThreshold
        request.requiresNetworkConnectivity = false

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
    func handleNotificationsRefresh(for processingTask: BGProcessingTask, using scheduler: Scheduler) {
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

    // TODO: when to call?
    func updateNotifications(using scheduler: Scheduler) async throws {
        // TODO: move first few lines to the scheduler, just pass in list of events that should be scheduled!

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
        // TODO: check if there are notifications enabled at all!

        // TODO: allow to skip querying the outcomes for more efficiency!
        // we query all future events until next month. We receive the result sorted
        let events = try scheduler.queryEvents(for: range, predicate: #Predicate { task in
            task.scheduleNotifications == true
        })
            // TODO: we can set the limit in the fetch already!
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
            // TODO: shall we register a refresh task anyways (there might be notifications in the future)!
            return // nothing got scheduled!
        }

        for event in schedulingEvents {
            // TODO: we might have notifications that got removed! (due to task changes (new task versions))
            //  => make sure that we also do the reverse check of, which events are not present anymore?
            //  => need information that pending notifications are part of our schedule? just cancel anything more in the future?
            guard !pendingNotifications.contains(SchedulerNotifications.notificationId(for: event)) else {
                // TODO: improve how we match existing notifications
                continue // TODO: if we allow to customize, we might need to check if the notification changed?
            }

            // TODO: support task cancellation!

            do {
                try await measure(name: "Notification Request") {
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
        "edu.stanford.spezi.scheduler.notification-taskId"
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
        "edu.stanford.spezi.scheduler.notification-category.\(category.rawValue)"
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
        "edu.stanford.spezi.scheduler.notification.event.\(event.occurrence.start)" // TODO: brint timeInterval since Reference?
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
