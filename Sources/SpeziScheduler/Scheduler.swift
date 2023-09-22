//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Combine
import Foundation
import OSLog
import Spezi
import SpeziLocalStorage
import SwiftUI
import UIKit
import UserNotifications


/// The ``Scheduler/Scheduler`` module allows the scheduling and observation of ``Task``s adhering to a specific ``Schedule``.
///
/// Use the ``Scheduler/Scheduler/init(tasks:)`` initializer or the ``Scheduler/Scheduler/schedule(task:)`` function
/// to schedule tasks that you can obtain using the ``Scheduler/Scheduler/tasks`` property.
/// You can use the ``Scheduler/Scheduler`` as an `ObservableObject` to automatically update your SwiftUI views when new events are emitted or events change.
public class Scheduler<Context: Codable>: NSObject, UNUserNotificationCenterDelegate, Module {
    @Dependency private var localStorage: LocalStorage
    
    public private(set) var tasks: [Task<Context>] = [] {
        didSet {
            guard oldValue != tasks else {
                return
            }
            
            _Concurrency.Task {
                await persistChanges()
            }
        }
    }
    @AppStorage("Spezi.Scheduler.firstlaunch") private var firstLaunch = true
    private var initialTasks: [Task<Context>]
    private var cancellables: Set<AnyCancellable> = []
    private let prescheduleNotificationLimit: Int
    private let localStorageLock = Lock()
    
    
    /// Indicates whether the necessary authorization to deliver local notifications is already granted.
    public var localNotificationAuthorization: Bool {
        get async {
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized
        }
    }
    
    
    /// Creates a new ``Scheduler`` module.
    /// - Parameter prescheduleLimit: The number of prescheduled notifications that should be registerd.
    ///                               Must be bigger than 1 and smaller than the limit of 64 local notifications at a time.
    ///                               We recommend setting the limit to a value lower than 64, e.g., 56, to ensure room inaccuracies in the iOS scheduling APIs.
    ///                               The default value is `56`.
    /// - Parameter tasks: The initial set of ``Task``s.
    public init(prescheduleNotificationLimit: Int = 56, tasks initialTasks: [Task<Context>] = []) {
        assert(
            prescheduleNotificationLimit >= 1 && prescheduleNotificationLimit <= 64,
            "The prescheduleLimit must be bigger than 1 and smaller than the limit of 64 local notifications at a time"
        )
        
        self.prescheduleNotificationLimit = prescheduleNotificationLimit
        self.initialTasks = initialTasks
        
        super.init()
        
        // Only run the notification setup when not running unit tests:
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            let notificationCenter = UNUserNotificationCenter.current()
            if firstLaunch {
                notificationCenter.removeAllDeliveredNotifications()
                notificationCenter.removeAllPendingNotificationRequests()
                firstLaunch = false
            }
        }
    }
    
    
    public func configure() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(timeZoneChanged),
            name: Notification.Name.NSSystemTimeZoneDidChange,
            object: nil
        )
        
        _Concurrency.Task {
            var storedTasks: [Task<Context>]? // swiftlint:disable:this discouraged_optional_collection
            
            await localStorageLock.enter {
                storedTasks = try? localStorage.read([Task<Context>].self, storageKey: Constants.taskStorageKey)
            }
            
            guard let storedTasks = storedTasks else {
                await schedule(tasks: initialTasks)
                return
            }
            
            await schedule(tasks: storedTasks)
        }
    }
    
    
    /// Presents the system authentication UI to send local notifications if the application is not yet permitted to send local notifications.
    public func requestLocalNotificationAuthorization() async throws {
        if await !localNotificationAuthorization {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            
            // Triggers an update of the UI in case the notification permissions are changed
            await sendObjectWillChange()
        }
    }
    
    /// Schedule a new ``Task`` in the ``Scheduler`` module.
    /// - Parameter task: The new ``Task`` instance that should be scheduled.
    public func schedule(task: Task<Context>) async {
        task.objectWillChange
            .sink {
                _Concurrency.Task {
                    await self.sendObjectWillChange()
                }
            }
            .store(in: &cancellables)
        
        tasks.append(task)
        
        self.updateTasks()
        if task.notifications {
            await self.updateScheduleNotifications()
        }
        await persistChanges()
        
        await sendObjectWillChange(skipInternalUpdates: true)
    }
    
    
    // MARK: - Lifecycle
    @_documentation(visibility: internal)
    public func willFinishLaunchingWithOptions(_ application: UIApplication, launchOptions: [UIApplication.LaunchOptionsKey: Any]) {
        UNUserNotificationCenter.current().delegate = self
    }
    
    @_documentation(visibility: internal)
    public func sceneWillEnterForeground(_ scene: UIScene) {
        _Concurrency.Task {
            await sendObjectWillChange()
        }
    }
    
    @_documentation(visibility: internal)
    public func applicationWillTerminate(_ application: UIApplication) {
        _Concurrency.Task {
            await persistChanges()
        }
    }
    
    
    // MARK: - Notification Center
    @_documentation(visibility: internal)
    @MainActor
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.badge, .banner, .sound, .list]
    }
    
    
    // MARK: - Helper Methods
    private func persistChanges() async {
        await localStorageLock.enter {
            do {
                try self.localStorage.store(self.tasks, storageKey: Constants.taskStorageKey)
            } catch {
                os_log(.error, "Spezi.Scheduler: Could not persist the tasks of the scheduler module: \(error)")
            }
        }
    }
    
    private func sendObjectWillChange(skipInternalUpdates: Bool = false) async {
        os_log(.debug, "Spezi.Scheduler: Object will change (skipInternalUpdates: \(skipInternalUpdates))")
        if skipInternalUpdates {
            await MainActor.run {
                self.objectWillChange.send()
            }
        } else {
            self.updateTasks()
            await updateScheduleNotifications()
            await persistChanges()
            await MainActor.run {
                self.objectWillChange.send()
            }
        }
    }
    
    
    @objc
    private func timeZoneChanged() {
        _Concurrency.Task {
            await sendObjectWillChange()
        }
    }
    
    private func schedule(tasks: [Task<Context>]) async {
        for task in tasks {
            await schedule(task: task)
        }
    }
    
    
    private func updateTasks() {
        for task in self.tasks {
            task.scheduleTask()
        }
    }
    
    private func updateScheduleNotifications() async {
        // Get all tasks that have notifications enabled and that have events in the future that are not yet complete.
        // Same as but there is a Swift compiler bug that is causing a crash using Swift 5.9 when archiving in a release build.
        // Check with newer Swift versions:
        // ```swift
        // let numberOfTasksWithNotifications = max(
        //     1,
        //     tasks.filter { $0.notifications && !$0.events(from: .now, complete: false).contains(where: { !$0.complete }) }.count
        // )
        // ```
        var numberOfTasksWithNotificationsCounter: Int = 0
        for task in tasks where task.notifications {
            let events = task.events(from: .now)
            
            guard events.contains(where: { !$0.complete }) else {
                continue
            }
            
            numberOfTasksWithNotificationsCounter += 1
        }
        let numberOfTasksWithNotifications = max(1, numberOfTasksWithNotificationsCounter)
        
        
        // Disable notification center interaction when running unit tests:
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }
        
        // First, remove all notifications from past events that are be complete.
        for task in self.tasks {
            for event in task.events {
                event.cancelNotification()
            }
        }
        
        let notificationCenter = UNUserNotificationCenter.current()
        
        if self.prescheduleNotificationLimit < numberOfTasksWithNotifications {
            os_log(.error, "Spezi.Scheduler: The preschedule notification limit \(self.prescheduleNotificationLimit) is smaller than the numer of tasks with active notifications: \(numberOfTasksWithNotifications)")
            assertionFailure("Please ensure that your preschedule notification limit is bigger than the teasks with active notifications")
        }
        
        let deliveredNotifications = await notificationCenter.deliveredNotifications().sorted(by: { $0.date < $1.date })
        let prescheduleNotificationLimit = max(self.prescheduleNotificationLimit - deliveredNotifications.count, 1)
        
        if prescheduleNotificationLimit < numberOfTasksWithNotifications {
            os_log(.error, "Spezi.Scheduler: The number of available notification slots is smaller than the numer of tasks with active notifications: \(numberOfTasksWithNotifications), removing the oldest \(numberOfTasksWithNotifications - prescheduleNotificationLimit) notifications.")
            
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
                for task in tasks where task.contains(scheduledNotificationWithId: identifier) {
                    notificationsThatMayBeRemovedIdentifiers.append(identifier)
                    break // Continue to the next deliveredNotification.
                }
            }
            let notificationsToBeRemovedIdentifier = Array(
                notificationsThatMayBeRemovedIdentifiers.prefix(upTo: max(0, numberOfTasksWithNotifications - prescheduleNotificationLimit))
            )
            
            notificationCenter.removeDeliveredNotifications(withIdentifiers: notificationsToBeRemovedIdentifier)
        }
        
        let prescheduleNotificationLimitPerTask = prescheduleNotificationLimit / numberOfTasksWithNotifications
        
        for task in self.tasks {
            await task.scheduleNotification(prescheduleNotificationLimitPerTask)
        }
        
        await persistChanges()
    }
}
