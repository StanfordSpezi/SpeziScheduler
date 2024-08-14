//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OSLog
import Spezi
import SwiftUI
@preconcurrency import UserNotifications


/// Schedule and observe `Task` according to a specified `Schedule`.
///
/// The `Scheduler` module helps with scheduling and observation ``Task``s according to the specified ``Schedule``.
///
/// Use the ``Scheduler/init(prescheduleNotificationLimit:tasks:)`` initializer or the ``Scheduler/schedule(task:)`` function
/// to schedule tasks that you can obtain using the ``Scheduler/tasks`` property.
/// You can use the ``Scheduler`` as an `ObservableObject` to automatically update your SwiftUI views when new events are emitted or events change.
@MainActor
public final class Scheduler<Context: Codable & Sendable>: Module, EnvironmentAccessible, DefaultInitializable, NotificationHandler, Sendable {
    private let logger = Logger(subsystem: "edu.stanford.spezi.scheduler", category: "Scheduler")

    @AppStorage("Spezi.Scheduler.firstlaunch")
    @MainActor private var firstLaunch = true
    private let initialTasks: [Task<Context>]
    private let prescheduleNotificationLimit: Int

    @MainActor private var taskList: TaskList<Context> {
        storage.taskList
    }

    @MainActor  public var tasks: [Task<Context>] {
        taskList.tasks
    }


    @Dependency(SchedulerStorage<Context>.self)
    private var storage

    @Modifier private var modifier = SchedulerLifecycle<Context>()


    /// Indicates whether the necessary authorization to deliver local notifications is already granted.
    public var localNotificationAuthorization: Bool {
        get async {
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized
        }
    }
    
    
    /// Creates a new ``Scheduler`` module.
    /// - Parameter prescheduleNotificationLimit: The number of prescheduled notifications that should be registered.
    ///                               Must be bigger than 1 and smaller than the limit of 64 local notifications at a time.
    ///                               We recommend setting the limit to a value lower than 64, e.g., 56, to ensure room inaccuracies in the iOS scheduling APIs.
    ///                               The default value is `56`.
    /// - Parameter initialTasks: The initial set of ``Task``s.
    public nonisolated init(prescheduleNotificationLimit: Int = 56, tasks initialTasks: [Task<Context>] = []) {
        assert(
            prescheduleNotificationLimit >= 1 && prescheduleNotificationLimit <= 64,
            "The prescheduleLimit must be bigger than 1 and smaller than the limit of 64 local notifications at a time"
        )
        
        self.prescheduleNotificationLimit = prescheduleNotificationLimit
        self.initialTasks = initialTasks
        
        // Only run the notification setup when not running unit tests:
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            let notificationCenter = UNUserNotificationCenter.current()
            if _firstLaunch.wrappedValue {
                notificationCenter.removeAllDeliveredNotifications()
                notificationCenter.removeAllPendingNotificationRequests()
                _firstLaunch.wrappedValue = false
            }
        }
    }

    public nonisolated required convenience init() {
        self.init(tasks: [])
    }
    
    
    public func configure() {
        _Concurrency.Task {
            let storedTasks = await storage.loadTasks()

            await schedule(tasks: storedTasks ?? initialTasks)
        }
    }
    
    
    /// Presents the system authentication UI to send local notifications if the application is not yet permitted to send local notifications.
    public func requestLocalNotificationAuthorization() async throws {
        if await !localNotificationAuthorization {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            
            // now we have permissions, schedule all notifications now
            await updateScheduleNotifications()
        }
    }
    
    /// Schedule a new ``Task`` in the ``Scheduler`` module.
    /// - Parameter task: The new ``Task`` instance that should be scheduled.
    @MainActor
    public func schedule(task: Task<Context>) async {
        taskList.append(task)

        for event in task.events { // make sure all events have a reference to the storage
            event.storage = storage
        }

        self.scheduleTasks()
        if task.notifications {
            await self.updateScheduleNotifications()
        }
        await storage.storeTasks() // we store the added tasks
    }
    
    
    @MainActor
    func handleActiveScenePhase() {
        logger.debug("Scene entered foreground. Scheduling Tasks...")
        self.scheduleTasks()
        _Concurrency.Task {
            await updateScheduleNotifications()
        }
    }


    @MainActor
    func handleApplicationWillTerminate() {
        _Concurrency.Task {
            await storage.storeTasks()
        }
    }
    
    
    // MARK: - Notification Center
    public func receiveIncomingNotification(_ notification: UNNotification) async -> UNNotificationPresentationOptions? {
        let id = notification.request.identifier
        let isSchedulerNotification = taskList.contains { task in
            task.events.contains { event in
                event.notification?.uuidString == id
            }
        }

        guard isSchedulerNotification else {
            return nil // we don't decide for notifications we didn't schedule
        }

        return [.badge, .banner, .sound, .list]
    }

    
    // MARK: - Helper Methods
    private func schedule(tasks: [Task<Context>]) async {
        for task in tasks {
            await schedule(task: task)
        }
    }
    

    /// Schedules all tasks.
    ///
    /// This method triggers the due timer. This ensures that all events are marked
    /// due once they pass their scheduled date.
    @MainActor
    private func scheduleTasks() {
        for task in taskList {
            task.scheduleTasks()
        }
    }
    

    @MainActor
    private func updateScheduleNotifications() async {
        // Disable notification center interaction when running unit tests:
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        // Get all tasks that have notifications enabled and that have events in the future that are not yet complete.
        // Same as below, but there is a Swift compiler bug that is causing a crash using Swift 5.9 when archiving in a release build.
        // Check with newer Swift versions:
        // ```swift
        // let numberOfTasksWithNotifications = max(
        //     1,
        //     tasks.filter { $0.notifications && !$0.events(from: .now, complete: false).contains(where: { !$0.complete }) }.count
        // )
        // ```
        var numberOfTasksWithNotificationsCounter: Int = 0
        for task in taskList where task.notifications {
            let events = task.events(from: .now)

            guard events.contains(where: { !$0.complete }) else {
                continue
            }

            numberOfTasksWithNotificationsCounter += 1
        }

        // First, remove all notifications from past events that are be complete.
        for task in self.taskList {
            for event in task.events {
                event.cancelNotification()
            }
        }


        let limit = await currentPerTaskNotificationLimit(numberOfTasksWithNotificationsCount: numberOfTasksWithNotificationsCounter)

        for task in taskList {
            await task.scheduleNotifications(limit)
        }
    }


    @MainActor
    private func currentPerTaskNotificationLimit(numberOfTasksWithNotificationsCount: Int) async -> Int {
        let numberOfTasksWithNotifications = max(1, numberOfTasksWithNotificationsCount)

        let notificationCenter = UNUserNotificationCenter.current()

        if self.prescheduleNotificationLimit < numberOfTasksWithNotifications {
            logger.error("The preschedule notification limit \(self.prescheduleNotificationLimit) is smaller than the number of tasks with active notifications: \(numberOfTasksWithNotifications).")
            assertionFailure("Please ensure that your preschedule notification limit is bigger than the tasks with active notifications")
        }

        let deliveredNotifications = await notificationCenter.deliveredNotifications().sorted(by: { $0.date < $1.date })
        let prescheduleNotificationLimit = max(self.prescheduleNotificationLimit - deliveredNotifications.count, 1)

        if prescheduleNotificationLimit < numberOfTasksWithNotifications {
            logger.error("The number of available notification slots is smaller than the number of tasks with active notifications: \(numberOfTasksWithNotifications), removing the oldest \(numberOfTasksWithNotifications - prescheduleNotificationLimit) notifications.")

            // Same as but there is a Swift compiler bug that is causing a crash using Swift 5.9 when archiving in a release build.
            // Check with newer Swift versions:
            // ```swift
            // let notificationsToBeRemoved = Array(deliveredNotifications
            //     .map(\.request.identifier)
            //     .filter { identifier in
            //         tasks.contains { task in
            //             task.contains(scheduledNotificationWithId: identifier)
            //         }
            //     }
            //     .prefix(max(0, numberOfTasksWithNotifications - prescheduleNotificationLimit)))

            var notificationsThatMayBeRemovedIdentifiers: [String] = []
            for deliveredNotification in deliveredNotifications {
                let identifier = deliveredNotification.request.identifier

                // Only remove notifications that have been scheduled by a task in the Scheduler module:
                for task in taskList where task.contains(scheduledNotificationWithId: identifier) {
                    notificationsThatMayBeRemovedIdentifiers.append(identifier)
                    break // Continue to the next deliveredNotification.
                }
            }
            let notificationsToBeRemovedIdentifier = Array(
                notificationsThatMayBeRemovedIdentifiers.prefix(upTo: max(0, numberOfTasksWithNotifications - prescheduleNotificationLimit))
            )

            notificationCenter.removeDeliveredNotifications(withIdentifiers: notificationsToBeRemovedIdentifier)
        }

        return prescheduleNotificationLimit / numberOfTasksWithNotifications
    }
}
