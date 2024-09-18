//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Algorithms
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
public final class SchedulerNotifications { // TODO: docs! entitltemenet for time-sensitive notification + background processing.
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
    private nonisolated let schedulerTimeLimit: TimeInterval // TODO: rename and make public

    public nonisolated let allDayTaskNotificationTime: NotificationTime

    public required convenience nonisolated init() {
        self.init(schedulerLimit: 30, schedulerTimeLimit: .seconds(1 * 60 * 60 * 24 * 7 * 4), allDayTaskNotificationTime: .init(hour: 9))
    }

    public nonisolated init(schedulerLimit: Int, schedulerTimeLimit: Duration, allDayTaskNotificationTime: NotificationTime) {
        self.schedulerLimit = schedulerLimit
        self.schedulerTimeLimit = Double(schedulerTimeLimit.components.seconds) // TODO: duration doesn't really make things easier!
        self.allDayTaskNotificationTime = allDayTaskNotificationTime
    }
    
    /// Configures the module.
    @_documentation(visibility: internal)
    public func configure() {
        purgeLegacyEventNotifications()
    }

    private func ensureAllSchedulerNotificationsCancelled() async {
        let pendingNotifications = await notifications.pendingNotificationRequests()
            .filter { request in
                request.identifier.starts(with: Self.baseNotificationId)
            }
            .map { $0.identifier }

        if !pendingNotifications.isEmpty {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: pendingNotifications)
        }
    }

    private func groupedPendingSchedulerNotifications(otherNotificationsCount: inout Int) async -> [String: UNNotificationRequest] {
        var otherNotifications = 0
        let result: [String: UNNotificationRequest] = await notifications.pendingNotificationRequests().reduce(into: [:]) { partialResult, request in
            if request.identifier.starts(with: Self.baseNotificationId) {
                partialResult[request.identifier] = request
            } else {
                otherNotifications += 1
            }
        }

        otherNotificationsCount = otherNotifications
        return result
    }

    func scheduleNotificationsUpdate(using scheduler: Scheduler) async {
        // TODO: use an async semaphore or similar (or just debounce multiple calls here!)

        let task = _Concurrency.Task { @MainActor in
            try await self.updateNotifications(using: scheduler)
        }

        let identifier = _Application.shared.beginBackgroundTask(withName: "Scheduler Notifications") {
            task.cancel()
        }

        defer {
            _Application.shared.endBackgroundTask(identifier)
        }

        do {
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
        } catch _ as CancellationError {
        } catch {
            logger.error("Failed to schedule notifications for tasks: \(error)")
        }
    }

    // TODO: move first few lines to the scheduler, just pass in list of events that should be scheduled!
    func updateNotifications(using scheduler: borrowing Scheduler) async throws { // swiftlint:disable:this function_body_length
        // TODO: remove siwfltint disable again?
        let now = Date.now // ensure consistency in queries

        let hasTasksWithNotificationsAtAll = try measure(name: "hasTasksWithNotifications") {
            try scheduler.hasTasksWithNotifications(for: now...)
        }


        guard hasTasksWithNotificationsAtAll else {
            // this check is important. We know that not a single task (from now on) has notifications enabled.
            // Therefore, we do not need to schedule a background task to refresh notifications

            // ensure task is cancelled
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: PermittedBackgroundTaskIdentifier.speziSchedulerNotificationsScheduling.rawValue)

            // however, ensure that we cancel previously scheduled notifications (e.g., if we refresh due to a change)
            await ensureAllSchedulerNotificationsCancelled()
            return
        }

        /// We have two general strategies to schedule notifications:
        /// * **Task-Level**: If the schedule can be expressed using a simple `DateComponents` match (see `Schedule/canBeScheduledAsCalendarTrigger(now:)`, we use a
        ///     repeating `UNCalendarNotificationTrigger` to schedule all future events of a task.
        /// * **Event-Label**: If we cannot express the recurrence of a task using a `UNCalendarNotificationTrigger` we schedule each event separately using a
        ///     `UNTimeIntervalNotificationTrigger`

        /// We can only schedule a limited amount of notifications at the same time.
        /// Therefore, we do the following to limit the number of `UNTimeIntervalNotificationTrigger`-based notifications.
        /// 1) We only consider the events within the `schedulerTimeLimit`.
        /// 2) Sort all events by their occurrence.
        /// 3) Take the first N events and schedule their notifications (with n being the `schedulerLimit`).
        /// 4) Update the schedule after 1 week or earlier if the last scheduled event has an earlier occurrence.

        var otherNotificationsCount = 0
        let pendingNotifications = await groupedPendingSchedulerNotifications(otherNotificationsCount: &otherNotificationsCount)

        // the amount of "slots" which would be currently available to other modules to schedule notifications.
        let remainingNotificationSlots = LocalNotifications.pendingNotificationsLimit - otherNotificationsCount - schedulerLimit

        // if remainingNotificationSlots is negative, we need to lower our limit, because there is simply not enough space for us
        let currentSchedulerLimit = min(schedulerLimit, schedulerLimit + remainingNotificationSlots)

        let range = now..<now.addingTimeInterval(schedulerTimeLimit)
        var nextOccurrenceCache = TaskNextOccurrenceCache(in: now...)

        // We query all future events until the schedulerTimeLimit. We generally aim to schedule things not too early so we apply the limit.
        // The results are sorted by their effective date. However, we additionally sort by the events first occurrence.
        var tasks = try scheduler.queryTasks(for: range, predicate: #Predicate { task in
            task.scheduleNotifications
        })
            .sorted { lhs, rhs in
                guard let lhsOccurrence = nextOccurrenceCache[lhs] else {
                    return nextOccurrenceCache[rhs] != nil
                }

                guard let rhsOccurrence = nextOccurrenceCache[rhs] else {
                    return false
                }

                return lhsOccurrence < rhsOccurrence
            }
            // we filter after sorting. using a fetchLimit before sorting could be more efficient, but this deliver better results
            .prefix(currentSchedulerLimit + 1)

        // to be able to efficiently schedule the next refresh, we need to know the next task that we didn't schedule anymore
        let nextTaskOccurrenceWeDidNotSchedule: Occurrence? = if tasks.count == currentSchedulerLimit + 1, let last = tasks.last {
            nextOccurrenceCache[last]
        } else {
            nil
        }

        tasks = tasks.prefix(currentSchedulerLimit) // correct the prefix

        // stable partition preserves relative order
        let pivot = tasks.stablePartition { task in
            // true, if it belongs into the second partition
            task.schedule.canBeScheduledAsRepeatingCalendarTrigger(allDayNotificationTime: allDayTaskNotificationTime, now: now)
        }

        let calendarTriggerTasks = tasks[pivot...]

        // only space left for events is what we not already scheduled with calendar-trigger-based notifications
        let eventCountLimit = currentSchedulerLimit - calendarTriggerTasks.count

        // We don't query the outcomes at all. So all events will seem like they are not completed.
        var events = scheduler.assembleEvents(for: range, tasks: tasks[..<pivot], outcomes: nil)
            .prefix(eventCountLimit + 1)

        // to be able to efficiently schedule the next refresh, we need to know the next event that we didn't schedule anymore
        let nextEventOccurrenceWeDidNotSchedule: Occurrence? = if events.count == eventCountLimit + 1, let last = events.last {
            last.occurrence
        } else {
            nil
        }

        events = events.prefix(eventCountLimit) // correct the prefix

        // remove all notifications that we do not plan to schedule
        let removedNotifications = Set(pendingNotifications.keys)
            .subtracting(calendarTriggerTasks.map { Self.notificationId(for: $0) })
            .subtracting(events.map { Self.notificationId(for: $0) })

        if !removedNotifications.isEmpty {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Array(removedNotifications))
        }

        // `pendingNotifications` might contain notifications that already got removed. We only use it to check against notification request
        // we know for sure got not removed. So we do not bother to provide a filtered representations
        try await taskLevelScheduling(tasks: calendarTriggerTasks, pending: pendingNotifications, using: scheduler)
        try await eventLevelScheduling(for: range, events: events, pending: pendingNotifications, using: scheduler)

        // If we schedule a task-level notification via repeating calendar-trigger that has a schedule that doesn't run
        // forever, we need to make sure the we cancel the trigger once the schedule ends.
        // We don't create repeating triggers if the task only has a single occurrence left. Therefore, re-scheduling
        // notifications shortly before the last task is getting scheduled is fine.
        let earliestTaskLevelOccurrenceNeedingCancellation = tasks // swiftlint:disable:this identifier_name
            .filter { task in
                !task.schedule.repeatsIndefinitely
            }
            .compactMap { task in
                task.schedule.lastOccurrence(ifIn: now..<Date.nextWeek)
            }
            .min()


        let earliest = [nextTaskOccurrenceWeDidNotSchedule, nextEventOccurrenceWeDidNotSchedule, earliestTaskLevelOccurrenceNeedingCancellation]
            .compactMap { $0 }
            .min()

        scheduleNotificationsRefresh(nextThreshold: earliest?.start)
    }

    private func shouldScheduleNotification(
        for identifier: String,
        with content: @autoclosure () -> UNMutableNotificationContent,
        pending: [String: UNNotificationRequest]
    ) -> Bool {
        guard let existingRequest = pending[identifier] else {
            return true
        }

        if existingRequest.content == content() {
            return false
        } else {
            // notification exists, but is outdated, so remove it and redo it
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [existingRequest.identifier])
            return true
        }
    }

    private func taskLevelScheduling(
        tasks: ArraySlice<Task>,
        pending pendingNotifications: [String: UNNotificationRequest],
        using scheduler: Scheduler
    ) async throws {
        for task in tasks {
            try _Concurrency.Task.checkCancellation()

            lazy var content = task.notificationContent()

            guard shouldScheduleNotification(for: Self.notificationId(for: task), with: content, pending: pendingNotifications) else {
                continue
            }

            guard let notificationMatchingHint = task.schedule.notificationMatchingHint,
                  let calendar = task.schedule.recurrence?.calendar else {
                continue // shouldn't happen, otherwise, wouldn't be here
            }

            let components = notificationMatchingHint.dateComponents(calendar: calendar, allDayNotificationTime: allDayTaskNotificationTime)

            do {
                // TODO: just propagate failed notification scheduling, this fucks with our bg task scheduling!
                try await measure(name: "Task Notification Request") {
                    try await task.scheduleNotification(notifications: notifications, hint: components)
                }
            } catch {
                logger.error("Failed to register remote notification for task \(task.id) for hint \(String(describing: notificationMatchingHint))")
            }
        }
    }

    private func eventLevelScheduling(
        for range: Range<Date>,
        events: ArraySlice<Event>,
        pending pendingNotifications: [String: UNNotificationRequest],
        using scheduler: Scheduler
    ) async throws {
        for event in events {
            try _Concurrency.Task.checkCancellation()

            lazy var content = event.task.notificationContent()

            guard shouldScheduleNotification(for: Self.notificationId(for: event), with: content, pending: pendingNotifications) else {
                continue
            }

            do {
                try await measure(name: "Event Notification Request") {
                    try await event.scheduleNotification(notifications: notifications, allDayNotificationTime: allDayTaskNotificationTime)
                }
            } catch {
                logger.error("Failed to register remote notification for task \(event.task.id) for date \(event.occurrence.start)")
            }
        }
    }
}


extension SchedulerNotifications: Module, DefaultInitializable {}


// MARK: - Background Tasks

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

        let nextWeek: Date = .nextWeek

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
}

// MARK: - Legacy Notifications

extension SchedulerNotifications {
    /// Cancel scheduled and delivered notifications of the legacy SpeziScheduler 1.0
    fileprivate func purgeLegacyEventNotifications() {
        let legacyStorageKey = "spezi.scheduler.tasks" // the legacy scheduler 1.0 used to store tasks at this location.

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
