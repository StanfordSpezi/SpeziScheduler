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
import SpeziFoundation
import SpeziLocalStorage
import SwiftData
import UserNotifications
import struct SwiftUI.AppStorage


/// Manage notifications for the Scheduler.
///
/// Notifications can be automatically scheduled for Tasks that are scheduled using the ``Scheduler`` module. You configure a Task for automatic notification scheduling by
/// setting the ``Task/scheduleNotifications`` property.
///
/// - Note: The `SchedulerNotifications` module is automatically configured by the `Scheduler` module using default configuration options. If you want to provide
///     custom configuration for the `SchedulerNotifications`, just include it in your `configuration` section of your
///     [`SpeziAppDelegate`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate) using
///     ``init(notificationLimit:schedulingInterval:allDayNotificationTime:automaticallyRequestProvisionalAuthorization:)``.
///
/// ### Automatic Scheduling
///
/// The `Schedule` of a `Task` supports specifying complex recurrence rules to describe how the `Event`s of a `Task` recur.
/// These can not always be mapped to repeating notification triggers. Therefore, events need to be scheduled individually requiring much more notification requests.
/// Apple limits the total pending notification requests to `64` per application. SpeziScheduler, by default, doesn't schedule more than `30` local notifications at a time.
///
/// - Warning: Make sure to add  the [Background Modes](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes)
///     capability and enable the **Background fetch** option.
///
/// SpeziScheduler automatically schedules background tasks to update the list of scheduled notifications.
///
/// ### Time Sensitive Notifications
/// All notifications for events that do not have an ``Schedule/Duration-swift.enum/allDay`` duration, are automatically scheduled as [time-sensitive](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel/timesensitive)
/// notifications.
///
/// - Important: Make sure to add the "Time Sensitive Notifications" entitlement to your application to support delivering time-sensitive notifications.
///
/// ### Notification Authorization
///
/// In order for a user to receive notifications, you have to [request authorization](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications#Explicitly-request-authorization-in-context)
/// from the user to deliver notifications.
///
/// By default, SpeziScheduler will try to request [provisional notification authorization](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications#Use-provisional-authorization-to-send-trial-notifications).
/// Provisional authorization doesn't require explicit user authorization, however limits notification to be delivered quietly to the notification center only.
/// To disable this behavior use the ``automaticallyRequestProvisionalAuthorization`` option.
///
/// - Important: To ensure that notifications are delivered as alerts and can play sound, request explicit authorization from the user.
///
/// ## Topics
///
/// ### Configuration
/// - ``init()``
/// - ``init(notificationLimit:schedulingInterval:allDayNotificationTime:automaticallyRequestProvisionalAuthorization:)``
///
/// ### Properties
/// - ``notificationLimit``
/// - ``schedulingInterval``
/// - ``allDayNotificationTime``
/// - ``automaticallyRequestProvisionalAuthorization``
///
/// ### Notification Identifiers
/// - ``notificationId(for:)-33tri``
/// - ``notificationId(for:)-8cchs``
/// - ``notificationCategory(for:)``
/// - ``notificationThreadIdentifier(for:)``
/// - ``notificationTaskIdKey``
@MainActor
public final class SchedulerNotifications {
    @Application(\.logger)
    private var logger

    // TODO: are we fine with notifications that are scheduled with provisional but access is later granted?
    // TODO: we need to get notified if after notification authorization changed! (e.g., after onboarding screen)
    //  => do we, we schedule with provisional?

    @Application(\.notificationSettings)
    private var notificationSettings
    @Application(\.requestNotificationAuthorization)
    private var requestNotificationAuthorization

    @Dependency(LocalNotifications.self)
    private var notifications
    @Dependency(LocalStorage.self)
    private var localStorage

    @StandardActor private var standard: any Standard

    /// The limit of notification requests that should be pre-scheduled at a time.
    ///
    /// This options limits the maximum amount of local notifications request that SpeziScheduler schedules.
    ///
    /// - Note: Default is `30`.
    public nonisolated let notificationLimit: Int
    /// The time period for which we should schedule events in advance.
    ///
    /// - Note: Default is `4` weeks.
    public nonisolated let schedulingInterval: TimeInterval

    /// The time at which we schedule notifications for all day events.
    ///
    /// - Note: Default is 9 AM.
    public nonisolated let allDayNotificationTime: NotificationTime
    
    /// Automatically request provisional notification authorization if notification authorization isn't determined yet.
    ///
    /// If the module attempts to schedule notifications for its task and detects that notification authorization isn't determined yet, it automatically
    /// requests [provisional notification authorization](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications#Use-provisional-authorization-to-send-trial-notifications).
    public nonisolated let automaticallyRequestProvisionalAuthorization: Bool // swiftlint:disable:this identifier_name

    /// Make sure we aren't running multiple notification scheduling at the same time.
    private let scheduleNotificationAccess = AsyncSemaphore()
    /// Small flag that helps us to debounce multiple calls to schedule notifications.
    ///
    /// This flag is set once the scheduling notifications task is queued and reset once it starts running.
    /// As we are running on the same actor, we know that if the flag is true, we do not need to start another task as we are still in the same call stack
    /// and the task that is about to run will still see our changes.
    private var queuedForNextTick = false

    private var backgroundTaskRegistered = false

    /// Store the earliest refresh date of the background task.
    ///
    /// In the case that background tasks are not enabled, we still want to schedule notifications on a best-effort approach.
    @AppStorage(SchedulerNotifications.earliestScheduleRefreshDateStorageKey)
    private var earliestScheduleRefreshDate: Date?

    /// Default configuration.
    public required convenience nonisolated init() {
        self.init(notificationLimit: 30)
    }
    
    /// Configure the scheduler notifications module.
    /// - Parameters:
    ///   - notificationLimit: The limit of notification requests that should be pre-scheduled at a time.
    ///   - schedulingInterval: The time period for which we should schedule events in advance.
    ///   - allDayNotificationTime: The time at which we schedule notifications for all day events.
    ///   - automaticallyRequestProvisionalAuthorization: Automatically request provisional notification authorization if notification authorization isn't determined yet.
    public nonisolated init(
        notificationLimit: Int = 30,
        schedulingInterval: Duration = .weeks(4),
        allDayNotificationTime: NotificationTime = NotificationTime(hour: 9),
        automaticallyRequestProvisionalAuthorization: Bool = true // swiftlint:disable:this identifier_name
    ) {
        self.notificationLimit = notificationLimit
        self.schedulingInterval = Double(schedulingInterval.components.seconds)
        self.allDayNotificationTime = allDayNotificationTime
        self.automaticallyRequestProvisionalAuthorization = automaticallyRequestProvisionalAuthorization
    }
    
    /// Configures the module.
    @_documentation(visibility: internal)
    public func configure() {
        purgeLegacyEventNotifications()
    }

    func scheduleNotificationsUpdate(using scheduler: Scheduler) {
        guard !queuedForNextTick else {
            return
        }

        queuedForNextTick = true
        _Concurrency.Task { @MainActor in
            queuedForNextTick = false
            await _scheduleNotificationsUpdate(using: scheduler)
        }
    }

    private func _scheduleNotificationsUpdate(using scheduler: Scheduler) async {
        try? await scheduleNotificationAccess.waitCheckingCancellation()
        guard !_Concurrency.Task.isCancelled else {
            return
        }

        defer {
            scheduleNotificationAccess.signal()
        }

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
}


extension SchedulerNotifications: Module, DefaultInitializable, EnvironmentAccessible {}


// MARK: - Notification Scheduling

extension SchedulerNotifications {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func updateNotifications(using scheduler: borrowing Scheduler) async throws {
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
        /// 1) We only consider the events within the `schedulingInterval`.
        /// 2) Sort all events by their occurrence.
        /// 3) Take the first N events and schedule their notifications (with n being the `schedulerLimit`).
        /// 4) Update the schedule after 1 week or earlier if the last scheduled event has an earlier occurrence.

        var otherNotificationsCount = 0
        let pendingNotifications = await groupedPendingSchedulerNotifications(otherNotificationsCount: &otherNotificationsCount)
        print("Pending notifications: \(pendingNotifications)") // TODO: remove!

        // the amount of "slots" which would be currently available to other modules to schedule notifications.
        let remainingNotificationSlots = LocalNotifications.pendingNotificationsLimit - otherNotificationsCount - notificationLimit

        // if remainingNotificationSlots is negative, we need to lower our limit, because there is simply not enough space for us
        let currentSchedulerLimit = min(notificationLimit, notificationLimit + remainingNotificationSlots)

        let range = now..<now.addingTimeInterval(schedulingInterval)
        var nextOccurrenceCache = TaskNextOccurrenceCache(in: now...)

        // We query all future events until the schedulingInterval. We generally aim to schedule things not too early so we apply the limit.
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
            // we filter after sorting. using a fetchLimit before sorting could be more efficient, but this delivers better results
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
            task.schedule.canBeScheduledAsRepeatingCalendarTrigger(allDayNotificationTime: allDayNotificationTime, now: now)
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

        let settings = await notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            guard automaticallyRequestProvisionalAuthorization else {
                logger.error("Could not schedule notifications. Authorization status is not yet determined.")
                // TODO: no we definitely need to get notified once we are allowed to schedule notifications?
                return
            }
            do {
                try await requestNotificationAuthorization(options: [.alert, .sound, .badge, .provisional])
                logger.debug("Request provisional notification authorization to deliver event notifications.")
            } catch {
                logger.error("Failed to request provisional notification authorization: \(error)")
                throw error
            }
        case .authorized, .provisional, .ephemeral:
            break // continue to schedule notifications
        case .denied:
            logger.debug("The user denied to receive notifications. Aborting to schedule notifications.")
            return
        @unknown default:
            logger.error("Unknown notification authorization status: \(String(describing: settings.authorizationStatus))")
            return
        }

        // `pendingNotifications` might contain notifications that already got removed. We only use it to check against notification request
        // we know for sure got not removed. So we do not bother to provide a filtered representations
        try await measure(name: "Task Notification Request") {
            // TODO: we need to check if the date trigger changed!
            try await taskLevelScheduling(tasks: calendarTriggerTasks, pending: pendingNotifications, using: scheduler)
        }
        try await measure(name: "Event Notification Request") {
            try await eventLevelScheduling(for: range, events: events, pending: pendingNotifications, using: scheduler)
        }

        // If we schedule a task-level notification via repeating calendar-trigger that has a schedule that doesn't run
        // forever, we need to make sure the we cancel the trigger once the schedule ends.
        // We don't create repeating triggers if the task only has a single occurrence left. Therefore, re-scheduling
        // notifications shortly before the last task is getting scheduled is fine.
        let earliestTaskLevelOccurrenceNeedingCancellation = tasks // swiftlint:disable:this identifier_name
            .filter { !$0.schedule.repeatsIndefinitely }
            .compactMap { $0.schedule.lastOccurrence(ifIn: now..<Date.nextWeek) }
            .min()


        let earliest = [nextTaskOccurrenceWeDidNotSchedule, nextEventOccurrenceWeDidNotSchedule, earliestTaskLevelOccurrenceNeedingCancellation]
            .compactMap { $0 }
            .min()

        guard let earliest else {
            // there is no task repeating task that ends sooner, there is no task we didn't schedule
            // and there is no event we didn't schedule. Therefore, we do not need to schedule a background task at all.
            return
        }

        scheduleNotificationsRefresh(nextThreshold: earliest.start) // TODO: debug that!
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

    private func taskLevelScheduling(
        tasks: ArraySlice<Task>,
        pending pendingNotifications: [String: UNNotificationRequest],
        using scheduler: Scheduler
    ) async throws {
        var scheduledNotifications = 0

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

            let components = notificationMatchingHint.dateComponents(calendar: calendar, allDayNotificationTime: allDayNotificationTime)

            // Notification scheduling only fails if there is something statically wrong (e.g., content issues or configuration issues)
            // If one fails, probably all fail. So just abort.
            // See https://developer.apple.com/documentation/usernotifications/unerror
            try await task.scheduleNotification(
                notifications: notifications,
                standard: standard as? SchedulerNotificationsConstraint,
                hint: components
            )
            scheduledNotifications += 1
        }

        if scheduledNotifications > 0 {
            logger.debug("Scheduled \(scheduledNotifications) task-level notifications.")
        }
    }

    private func eventLevelScheduling(
        for range: Range<Date>,
        events: ArraySlice<Event>,
        pending pendingNotifications: [String: UNNotificationRequest],
        using scheduler: Scheduler
    ) async throws {
        var scheduledNotifications = 0

        for event in events {
            try _Concurrency.Task.checkCancellation()

            lazy var content = event.task.notificationContent()

            guard shouldScheduleNotification(for: Self.notificationId(for: event), with: content, pending: pendingNotifications) else {
                continue
            }

            try await event.scheduleNotification(
                notifications: notifications,
                standard: standard as? SchedulerNotificationsConstraint,
                allDayNotificationTime: allDayNotificationTime
            )
            scheduledNotifications += 1
        }

        if scheduledNotifications > 0 {
            logger.debug("Scheduled \(scheduledNotifications) event-level notifications.")
        }
    }
}


// MARK: - NotificationHandler

extension SchedulerNotifications: NotificationHandler {
    public func receiveIncomingNotification(_ notification: UNNotification) async -> UNNotificationPresentationOptions? {
        guard notification.request.identifier.starts(with: Self.baseNotificationId) else {
            return nil // we are not responsible
        }

        return [.list, .badge, .banner, .sound] // TODO: configurable?
    }
}


// MARK: - Background Tasks

extension SchedulerNotifications {
    @usableFromInline static var uiBackgroundModes: Set<BackgroundMode> {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        return modes.map { modes in
            modes.reduce(into: Set()) { partialResult, rawValue in
                partialResult.insert(BackgroundMode(rawValue: rawValue))
            }
        } ?? []
    }

    @inlinable static var backgroundFetchEnabled: Bool {
        uiBackgroundModes.contains(.fetch)
    }

    func registerProcessingTask(using scheduler: Scheduler) {
        defer {
            // fallback plan if we do not have background fetch enabled
            if let earliestScheduleRefreshDate, !backgroundTaskRegistered, earliestScheduleRefreshDate > .now {
                scheduleNotificationsUpdate(using: scheduler)
            }
        }

        guard Self.backgroundFetchEnabled else {
            logger.debug("Background fetch is not enabled. Skipping registering background task for notification scheduling.")
            return
        }

        backgroundTaskRegistered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: PermittedBackgroundTaskIdentifier.speziSchedulerNotificationsScheduling.rawValue,
            using: .main
        ) { [weak scheduler, weak self] task in
            guard let self,
                  let scheduler,
                  let backgroundTask = task as? BGAppRefreshTask else {
                return
            }
            MainActor.assumeIsolated {
                handleNotificationsRefresh(for: backgroundTask, using: scheduler)
            }
        }
    }

    private func scheduleNotificationsRefresh(nextThreshold: Date? = nil) {
        let nextWeek: Date = .nextWeek

        let earliestBeginDate = if let nextThreshold {
            min(nextWeek, nextThreshold)
        } else {
            nextWeek
        }


        earliestScheduleRefreshDate = earliestBeginDate

        if backgroundTaskRegistered {
            let request = BGAppRefreshTaskRequest(identifier: PermittedBackgroundTaskIdentifier.speziSchedulerNotificationsScheduling.rawValue)
            request.earliestBeginDate = earliestBeginDate

            do {
                try BGTaskScheduler.shared.submit(request)
                logger.debug("Scheduled background task with earliest begin date \(earliestBeginDate)")
            } catch {
                logger.error("Failed to schedule notifications processing task for SpeziScheduler: \(error)")
            }
        } else {
            logger.debug("Setting earliest schedule refresh to \(earliestBeginDate). Will attempt to update schedule on next app launch.")
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

// swiftlint:disable:this file_length
