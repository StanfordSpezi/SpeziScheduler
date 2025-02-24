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
///     customize the configuration, just provide the configured module in your `configuration` section of your
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
public final class SchedulerNotifications: Module, DefaultInitializable, EnvironmentAccessible, Sendable {
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
    
    private let cal = Calendar.current

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
            await self.checkForInitialScheduling(scheduler: scheduler)
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
            try await scheduleNotifications(for: scheduler)
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


// MARK: - Notification Scheduling

extension SchedulerNotifications {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func scheduleNotifications(for scheduler: borrowing Scheduler) async throws {
        // 1: remove all pending notification requests scheduled by SpeziScheduler
        await notifications.removePendingNotificationRequests { request in
            request.isSpeziSchedulerRequest
        }
        
        // 2: cancel any pending/upcoming background notification scheduling registrations
        #if !(os(macOS) || os(watchOS))
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: PermittedBackgroundTaskIdentifier.speziSchedulerNotificationsScheduling.rawValue)
        #endif
        earliestScheduleRefreshDate = nil
        
        let now = Date.now // ensure consistency in queries
        guard try scheduler.hasTasksWithNotifications(for: now...) else {
            // this check is important. We know that not a single task (from now on) has notifications enabled.
            // Therefore, we do not need to schedule a background task to refresh notifications, or do anything else.
            return
        }
        
        // 3: create new requests, based on the tasks, their schedules, etc
        
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
        
        /// the amount of "slots" which would be currently available to other modules to schedule notifications.
        let remainingNotificationSlots = await Notifications.pendingNotificationsLimit
            - notifications.pendingNotificationRequests().count
            - notificationLimit
        // if remainingNotificationSlots is negative, we need to lower our limit, because there is simply not enough space for us
        let currentSchedulerLimit = min(notificationLimit, notificationLimit + remainingNotificationSlots)
        
        let range = now..<now.addingTimeInterval(schedulingInterval)
        
        var upcomingEventsByTask: [[Event]] = try scheduler.queryTasks(for: range, predicate: #Predicate { $0.scheduleNotifications })
            .map { task in
                try scheduler.queryEvents(for: task, in: range).filter { !$0.isCompleted }
            }
        var numScheduledNotificationRequests = 0
        // as long as possible ...
        while true {
            // ... while we haven't yet reached the notification scheduling limits, and while there are still un-scheduled events ...
            guard numScheduledNotificationRequests < currentSchedulerLimit, upcomingEventsByTask.contains(where: { !$0.isEmpty }) else {
                break
            }
            // ... we go over each task's list of upcoming events ...
            for idx in upcomingEventsByTask.indices {
                var upcomingEventsForCurrentTask: [Event] {
                    get { upcomingEventsByTask[idx] }
                    set { upcomingEventsByTask[idx] = newValue }
                }
                // ... make sure that there are events left for this task (which haven't been scheduled yet) ...
                guard let event = upcomingEventsForCurrentTask.first else {
                    // ... if no events are left for this task we can immediately continue onto the next one
                    continue
                }
                // ... we check whether this task's events are equidistant wrt to their start dates ...
                let eventsDistances = upcomingEventsForCurrentTask.adjacentPairs().map { event0, event1 in
                    // Note that we're intentionally using DateComponents here, instead of simply calling timeIntervalSince;
                    // the reason being that the Calendar/DateComponents approach will be correct w.r.t. to eg leap years, DST transitions, etc.
                    cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: event0.occurrence.start, to: event1.occurrence.start)
                }
                if upcomingEventsForCurrentTask.count > 1,
                   Set(eventsDistances).count == 1,
                   let hint = event.task.schedule.notificationMatchingHint,
                   event.task.schedule.canBeScheduledAsRepeatingCalendarTrigger(allDayNotificationTime: allDayNotificationTime, now: now)
                {
                    // ... if they are (and we actually have multiple events), we can schedule them via a single, repeating UNCalendarNotificationTrigger ...
                    let content = event.task.notificationContent()
                    if let standard = standard as? any SchedulerNotificationsConstraint {
                        standard.updateNotificationContent(for: event, content: content)
                    }
                    let cal = event.task.schedule.recurrence?.calendar ?? cal
                    try await notifications.add(request: UNNotificationRequest(
                        identifier: Self.notificationId(for: event.task),
                        content: content,
                        trigger: UNCalendarNotificationTrigger(
                            //dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: event.occurrence.start),
                            dateMatching: hint.dateComponents(calendar: cal, allDayNotificationTime: allDayNotificationTime),
                            repeats: true
                        )
                    ))
                    numScheduledNotificationRequests += 1
                    // ... we have scheduled all events for this task, and can therefore remove them all from our workset
                    upcomingEventsForCurrentTask.removeAll()
                } else {
                    // ... if the events are not spaced equidistant, we need to schedule them individually
                    upcomingEventsForCurrentTask.removeFirst()
                    let content = event.task.notificationContent()
                    if let standard = standard as? any SchedulerNotificationsConstraint {
                        standard.updateNotificationContent(for: event, content: content)
                    }
                    let notificationDate = Schedule.notificationTime(
                        for: event.occurrence.start,
                        duration: event.occurrence.schedule.duration,
                        allDayNotificationTime: allDayNotificationTime
                    )
                    try await notifications.add(request: UNNotificationRequest(
                        identifier: Self.notificationId(for: event),
                        content: content,
                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: notificationDate.timeIntervalSinceNow, repeats: false)
                    ))
                    numScheduledNotificationRequests += 1
                }
            }
        }
        
        if let earliestNonScheduledEvent = upcomingEventsByTask.flatMap({ $0 }).min(by: { $0.occurrence.start < $1.occurrence.start }) {
            // register a background refresh for the earliest event we did not schedule a notification for
            scheduleNotificationsRefresh(nextThreshold: earliestNonScheduledEvent.occurrence.start)
        }
    }
}


// MARK: - NotificationHandler

extension SchedulerNotifications: NotificationHandler {
    public func receiveIncomingNotification(_ notification: UNNotification) async -> UNNotificationPresentationOptions? {
        guard notification.request.isSpeziSchedulerRequest else {
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

    private func scheduleNotificationsRefresh(nextThreshold: Date = .nextWeek) {
        let earliestBeginDate = min(nextThreshold, .nextWeek)

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
                try await scheduleNotifications(for: scheduler)
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


extension UNNotificationRequest {
    var isSpeziSchedulerRequest: Bool {
        identifier.starts(with: SchedulerNotifications.baseNotificationId)
    }
}

// swiftlint:disable:this file_length
