//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Algorithms
#if canImport(BackgroundTasks) // not available on watchOS
import BackgroundTasks
#endif
import Foundation
import Spezi
import SpeziFoundation
import SpeziLocalStorage
import SpeziNotifications
import SwiftData
import UserNotifications
import struct SwiftUI.AppStorage


/// Manage notifications for the Scheduler.
///
/// Notifications can be automatically scheduled for Tasks that are scheduled using the ``Scheduler`` module. You configure a Task for automatic notification scheduling by
/// setting the ``Task/scheduleNotifications`` property.
///
/// - Note: The `SchedulerNotifications` module is automatically configured by the `Scheduler` module using default configuration options. If you want to
///     custom the configuration, just provide the configured module in your `configuration` section of your
///     [`SpeziAppDelegate`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate).
///
/// ### Automatic Scheduling
///
/// The ``Schedule`` of a ``Task`` supports specifying complex recurrence rules to describe how the ``Event``s of a `Task` recur.
/// These can not always be mapped to repeating notification triggers. Therefore, events need to be scheduled individually requiring much more notification requests.
/// Apple limits the total pending notification requests to `64` per application. SpeziScheduler, by default, doesn't schedule more than `30` local notifications at a time for events
/// that occur within the next 4 weeks.
///
/// - Important: Make sure to add  the [Background Modes](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes)
///     capability and enable the **Background fetch** option. SpeziScheduler automatically schedules background tasks to update the scheduled notifications.
///     Background tasks are currently not supported on watchOS. Background tasks are generally not supported on macOS.
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
/// - Important: To ensure that notifications are delivered as alerts and can play sound, request explicit authorization from the user. Once the user received their first provisional notification
///     and taped the "Keep" button, notifications will always be delivered quietly but the authorization status will change to `authorized`, making it impossible to request notification authorization
///     for alert-based notification again.
///
/// There are cases where we cannot reliably detect when to re-schedule notifications. For example a user might turn off notifications in the settings app and turn them back on without ever
/// opening the application. In these cases, we never have the opportunity to schedule or update notifications if the users doesn't open up the application again.
///
/// - Important: If you disable ``automaticallyRequestProvisionalAuthorization``, make sure to call ``Scheduler/manuallyScheduleNotificationRefresh()`` once
///     you requested notification authorization from the user. Otherwise, SpeziScheduler won't schedule notifications properly.
///
/// ## Topics
///
/// ### Configuration
/// - ``init()``
/// - ``init(notificationLimit:schedulingInterval:allDayNotificationTime:notificationPresentation:automaticallyRequestProvisionalAuthorization:)``
///
/// ### Properties
/// - ``notificationLimit``
/// - ``schedulingInterval``
/// - ``allDayNotificationTime``
/// - ``notificationPresentation``
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

    @Application(\.notificationSettings)
    private var notificationSettings
    @Application(\.requestNotificationAuthorization)
    private var requestNotificationAuthorization

    @Dependency(Notifications.self)
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

    /// Defines the presentation of scheduler notifications if they are delivered when the app is in foreground.
    public nonisolated let notificationPresentation: UNNotificationPresentationOptions

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
    @AppStorage(SchedulerNotifications.authorizationDisallowedLastSchedulingStorageKey)
    private var authorizationDisallowedLastScheduling = false

    @Modifier private var scenePhaseRefresh = NotificationScenePhaseScheduling()

    /// Default configuration.
    public required convenience nonisolated init() {
        self.init(notificationLimit: 30)
    }
    
    /// Configure the scheduler notifications module.
    /// - Parameters:
    ///   - notificationLimit: The limit of notification requests that should be pre-scheduled at a time.
    ///   - schedulingInterval: The time period for which we should schedule events in advance.
    ///     The interval must be greater than one week.
    ///   - allDayNotificationTime: The time at which we schedule notifications for all day events.
    ///   - notificationPresentation: Defines the presentation of scheduler notifications if they are delivered when the app is in foreground.
    ///   - automaticallyRequestProvisionalAuthorization: Automatically request provisional notification authorization if notification authorization isn't determined yet.
    public nonisolated init(
        notificationLimit: Int = 30,
        schedulingInterval: Duration = .weeks(4),
        allDayNotificationTime: NotificationTime = NotificationTime(hour: 9),
        notificationPresentation: UNNotificationPresentationOptions = [.list, .badge, .banner, .sound],
        automaticallyRequestProvisionalAuthorization: Bool = true // swiftlint:disable:this identifier_name
    ) {
        self.notificationLimit = notificationLimit
        self.schedulingInterval = Double(schedulingInterval.components.seconds)
        self.allDayNotificationTime = allDayNotificationTime
        self.notificationPresentation = notificationPresentation
        self.automaticallyRequestProvisionalAuthorization = automaticallyRequestProvisionalAuthorization

        precondition(schedulingInterval >= .weeks(1), "The scheduling interval must be at least 1 week.")
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

    func registerProcessingTask(using scheduler: Scheduler) {
        if Self.backgroundFetchEnabled {
            #if os(macOS) || os(watchOS)
            preconditionFailure("BackgroundFetch was enabled even though it isn't supported on this platform.")
            #else
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
            #endif
        } else {
            #if os(macOS)
            logger.debug("Background fetch is not supported. Skipping registering background task for notification scheduling.")
            #elseif os(watchOS)
            logger.debug("Background fetch is currently not supported. Skipping registering background task for notification scheduling.")
            #else
            logger.debug("Background fetch is not enabled. Skipping registering background task for notification scheduling.")
            #endif
        }

        _Concurrency.Task { @MainActor in
            await checkForInitialScheduling(scheduler: scheduler)
        }
    }

    func checkForInitialScheduling(scheduler: Scheduler) async {
        var scheduleNotificationUpdate = false

        if authorizationDisallowedLastScheduling {
            let status = await notificationSettings().authorizationStatus
            let nowAllowed = switch status {
            case .notDetermined, .denied:
                false
            case .authorized, .provisional, .ephemeral:
                true
            @unknown default:
                false
            }

            if nowAllowed {
                logger.debug("Notification Authorization now allows scheduling. Scheduling notifications...")
                scheduleNotificationUpdate = true
            }
        }

        // fallback plan if we do not have background fetch enabled
        if !backgroundTaskRegistered, let earliestScheduleRefreshDate, earliestScheduleRefreshDate > .now {
            logger.debug("Background task failed to register and we passed earliest refresh date. Manually scheduling...")
            scheduleNotificationUpdate = true
        }

        if scheduleNotificationUpdate {
            scheduleNotificationsUpdate(using: scheduler)
        }
    }

    private func _scheduleNotificationsUpdate(using scheduler: Scheduler) async {
        do {
            try await scheduleNotificationAccess.waitCheckingCancellation()
        } catch {
            return // cancellation
        }

        defer {
            scheduleNotificationAccess.signal()
        }

        let task = _Concurrency.Task { @MainActor in
            try await self.updateNotifications(using: scheduler)
        }

        #if !os(macOS) && !os(watchOS)
        let identifier = _Application.shared.beginBackgroundTask(withName: "Scheduler Notifications") {
            task.cancel()
        }

        defer {
            _Application.shared.endBackgroundTask(identifier)
        }
        #endif

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
#if !os(macOS) && !os(watchOS)
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: PermittedBackgroundTaskIdentifier.speziSchedulerNotificationsScheduling.rawValue)
#endif
            earliestScheduleRefreshDate = nil

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

        // the amount of "slots" which would be currently available to other modules to schedule notifications.
        let remainingNotificationSlots = Notifications.pendingNotificationsLimit - otherNotificationsCount - notificationLimit

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
        let nextTaskOccurrenceWeDidNotSchedule: Date? = if tasks.count == currentSchedulerLimit + 1, let last = tasks.last {
            nextOccurrenceCache[last]?.start
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
        let nextEventOccurrenceWeDidNotSchedule: Date? = if events.count == eventCountLimit + 1, let last = events.last {
            last.occurrence.start
        } else {
            nil
        }

        // We might query less than `eventCountLimit` events, but there might be events scheduled after our `schedulingInterval`.
        // Therefore,
        let hasEventOccurrenceNextMonth = scheduler.hasEventOccurrence(in: range.upperBound..<Date.distantFuture, tasks: tasks)

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
                authorizationDisallowedLastScheduling = true
                return
            }
            do {
                try await requestNotificationAuthorization(options: [.alert, .sound, .badge, .provisional])
                logger.debug("Request provisional notification authorization to deliver event notifications.")
            } catch {
                logger.error("Failed to request provisional notification authorization: \(error)")
                authorizationDisallowedLastScheduling = true
                throw error
            }
        case .authorized, .provisional, .ephemeral:
            break // continue to schedule notifications
        case .denied:
            logger.debug("The user denied to receive notifications. Aborting to schedule notifications.")
            authorizationDisallowedLastScheduling = true
            return
        @unknown default:
            logger.error("Unknown notification authorization status: \(String(describing: settings.authorizationStatus))")
            authorizationDisallowedLastScheduling = true // we basically retry
            return
        }

        authorizationDisallowedLastScheduling = false

        // `pendingNotifications` might contain notifications that already got removed. We only use it to check against notification request
        // we know for sure got not removed. So we do not bother to provide a filtered representations
        try await measure(name: "Task Notification Request") {
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
            .map { $0.schedule.lastOccurrence(ifIn: now..<Date.nextWeek)?.start ?? .nextWeek }
            .min()


        let earliest = [
            nextTaskOccurrenceWeDidNotSchedule,
            nextEventOccurrenceWeDidNotSchedule,
            earliestTaskLevelOccurrenceNeedingCancellation,
            hasEventOccurrenceNextMonth ? range.upperBound : nil
        ]
            .compactMap { $0 }
            .min()

        guard let earliest else {
            // there is no task repeating task that ends sooner, there is no task we didn't schedule
            // and there is no event we didn't schedule. Therefore, we do not need to schedule a background task at all.
            earliestScheduleRefreshDate = nil
            return
        }

        scheduleNotificationsRefresh(nextThreshold: earliest)
    }

    private func shouldScheduleNotification(
        for identifier: String,
        with content: @autoclosure () -> UNMutableNotificationContent,
        trigger: @autoclosure () -> UNNotificationTrigger,
        pending: [String: UNNotificationRequest]
    ) -> Bool {
        guard let existingRequest = pending[identifier] else {
            return true
        }

        if existingRequest.content == content() && existingRequest.trigger == trigger() {
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

            guard let notificationMatchingHint = task.schedule.notificationMatchingHint,
                  let calendar = task.schedule.recurrence?.calendar else {
                continue // shouldn't happen, otherwise, wouldn't be here
            }

            let components = notificationMatchingHint.dateComponents(calendar: calendar, allDayNotificationTime: allDayNotificationTime)

            lazy var content = {
                let content = task.notificationContent()
                if let standard = standard as? any SchedulerNotificationsConstraint {
                    standard.notificationContent(for: task, content: content)
                }
                return content
            }()
            lazy var trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let id = Self.notificationId(for: task)
            guard shouldScheduleNotification(for: id, with: content, trigger: trigger, pending: pendingNotifications) else {
                continue
            }

            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            // Notification scheduling only fails if there is something statically wrong (e.g., content issues or configuration issues)
            // If one fails, probably all fail. So just abort.
            // See https://developer.apple.com/documentation/usernotifications/unerror
            try await notifications.add(request: request)

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

            lazy var content = {
                let content = event.task.notificationContent()
                if let standard = standard as? any SchedulerNotificationsConstraint {
                    standard.notificationContent(for: event.task, content: content)
                }
                return content
            }()

            let notificationTime = Schedule.notificationTime(
                for: event.occurrence.start,
                duration: event.occurrence.schedule.duration,
                allDayNotificationTime: allDayNotificationTime
            )

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: notificationTime.timeIntervalSinceNow, repeats: false)

            let id = Self.notificationId(for: event)
            guard shouldScheduleNotification(for: id, with: content, trigger: trigger, pending: pendingNotifications) else {
                continue
            }

            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try await notifications.add(request: request)

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

        return notificationPresentation
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
#if os(macOS) || os(watchOS)
        false
#else
        uiBackgroundModes.contains(.fetch)
#endif
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
            #if os(macOS) || os(watchOS)
            preconditionFailure("Background Task was set to be registered, but isn't available on this platform.")
            #else
            let request = BGAppRefreshTaskRequest(identifier: PermittedBackgroundTaskIdentifier.speziSchedulerNotificationsScheduling.rawValue)
            request.earliestBeginDate = earliestBeginDate

            do {
                logger.debug("Scheduling background task with earliest begin date \(earliestBeginDate)...")
                try BGTaskScheduler.shared.submit(request)
            } catch let error as BGTaskScheduler.Error {
#if targetEnvironment(simulator)
                if case .unavailable = error.code {
                    logger.warning(
                            """
                            Failed to schedule notifications processing task for SpeziScheduler: \
                            Background tasks are not available on simulator devices!
                            """
                    )
                    return
                }
#endif
                logger.error("Failed to schedule notifications processing task for SpeziScheduler: \(error.code)")
            } catch {
                logger.error("Failed to schedule notifications processing task for SpeziScheduler: \(error)")
            }
            #endif
        } else {
            logger.debug("Setting earliest schedule refresh to \(earliestBeginDate). Will attempt to update schedule on next app launch.")
        }
    }

#if !os(watchOS)
    /// Call to handle execution of the background processing task that updates scheduled notifications.
    /// - Parameters:
    ///   - processingTask:
    ///   - scheduler: The scheduler to retrieve the events from.
    @available(macOS, unavailable)
    private func handleNotificationsRefresh(for processingTask: BGAppRefreshTask, using scheduler: Scheduler) {
        let task = _Concurrency.Task { @MainActor in
            do {
                try await scheduleNotificationAccess.waitCheckingCancellation()
            } catch {
                return // cancellation
            }

            defer {
                scheduleNotificationAccess.signal()
            }

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
#endif
}

// MARK: - Legacy Notifications

extension LocalStorageKeys {
    fileprivate static let legacyTasks = LocalStorageKey<[LegacyTaskModel]>(
        "spezi.scheduler.tasks", // the legacy scheduler 1.0 used to store tasks at this location.
        setting: .encryptedUsingKeychain(),
        encoder: JSONEncoder(),
        decoder: JSONDecoder()
    )
}

extension SchedulerNotifications {
    /// Cancel scheduled and delivered notifications of the legacy SpeziScheduler 1.0
    fileprivate func purgeLegacyEventNotifications() {
        let legacyTasks: [LegacyTaskModel]
        do {
            legacyTasks = try localStorage.load(.legacyTasks) ?? []
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
            try localStorage.delete(.legacyTasks)
        } catch {
            logger.warning("Failed to remove legacy scheduler task storage: \(error)")
        }
    }
}

// swiftlint:disable:this file_length
