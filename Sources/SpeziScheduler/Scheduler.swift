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
            
            persistChanges()
        }
    }
    @AppStorage("Spezi.Scheduler.firstlaunch") private var firstLaunch = true
    private var initialTasks: [Task<Context>]
    private var cancellables: Set<AnyCancellable> = []
    private let prescheduleNotificationLimit: Int
    
    /// Indicates whether the necessary authorization to deliver local notifications is already granted.
    public var localNotificationAuthorization: Bool {
        get async {
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized
        }
    }
    
    /// Creates a new ``Scheduler`` module.
    /// - Parameter prescheduleLimit: The number of prescheduled notifications that should be registerd.
    ///                               Must be bigger than 1 and smaller than the limit of 64 local notifications at a time.
    /// - Parameter tasks: The initial set of ``Task``s.
    public init(prescheduleNotificationLimit: Int = 64, tasks initialTasks: [Task<Context>] = []) {
        assert(
            prescheduleNotificationLimit >= 1 && prescheduleNotificationLimit <= 64,
            "The prescheduleLimit must be bigger than 1 and smaller than the limit of 64 local notifications at a time"
        )
        
        self.prescheduleNotificationLimit = prescheduleNotificationLimit
        self.initialTasks = initialTasks
        
        super.init()
        
        let notificationCenter = UNUserNotificationCenter.current()
        if firstLaunch {
            notificationCenter.removeAllDeliveredNotifications()
            notificationCenter.removeAllPendingNotificationRequests()
            firstLaunch = false
        }
    }
    
    
    public func configure() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(timeZoneChanged),
            name: Notification.Name.NSSystemTimeZoneDidChange,
            object: nil
        )
        
        self.objectWillChange
            .throttle(for: .seconds(0.25), scheduler: RunLoop.main, latest: true)
            .sink {
                self.updateScheduleTaskAndNotifications()
                self.persistChanges()
            }
            .store(in: &cancellables)
        
        
        guard let storedTasks = try? localStorage.read([Task<Context>].self) else {
            schedule(tasks: initialTasks)
            return
        }
        
        schedule(tasks: storedTasks)
    }
    
    
    /// Presents the system authentication UI to send local notifications if the application is not yet permitted to send local notifications.
    public func requestLocalNotificationAuthorization() async throws {
        if await !localNotificationAuthorization {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            
            // Triggers an update of the UI in case the notification permissions are changed
            sendObjectWillChange()
        }
    }
    
    public func willFinishLaunchingWithOptions(_ application: UIApplication, launchOptions: [UIApplication.LaunchOptionsKey: Any]) {
        UNUserNotificationCenter.current().delegate = self
    }
    
    public func applicationWillTerminate(_ application: UIApplication) {
        persistChanges()
    }
    
    // Unfortunately, the async overload of the `UNUserNotificationCenterDelegate` results in a runtime crash.
    // Reverify this in iOS versions after iOS 17.0
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        sendObjectWillChange()
        completionHandler()
    }
    
    // Unfortunately, the async overload of the `UNUserNotificationCenterDelegate` results in a runtime crash.
    // Reverify this in iOS versions after iOS 17.0
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        sendObjectWillChange()
        completionHandler([.badge, .banner, .sound])
    }
    
    public func sceneWillEnterForeground(_ scene: UIScene) {
        sendObjectWillChange()
    }
    
    
    /// Schedule a new ``Task`` in the ``Scheduler`` module.
    /// - Parameter task: The new ``Task`` instance that should be scheduled.
    public func schedule(task: Task<Context>) {
        task.objectWillChange
            .receive(on: RunLoop.main)
            .sink {
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        tasks.append(task)
        self.sendObjectWillChange()
    }
    
    func persistChanges() {
        do {
            try self.localStorage.store(self.tasks)
        } catch {
            os_log(.error, "Could not persist the tasks of the scheduler module: \(error)")
        }
    }
    
    func sendObjectWillChange() {
        _Concurrency.Task { @MainActor in
            self.objectWillChange.send()
        }
    }
    
    @objc
    private func timeZoneChanged() {
        sendObjectWillChange()
    }
    
    private func schedule(tasks: [Task<Context>]) {
        for task in tasks {
            schedule(task: task)
        }
    }
    
    private func updateScheduleTaskAndNotifications() {
        _Concurrency.Task {
            let notificationCenter = UNUserNotificationCenter.current()
            
            // Get all tasks that have notifications enabled and that have events in the future.
            let numberOfTasksWithNotifications = max(1, tasks.filter { $0.notifications && !$0.events(from: .now).isEmpty }.count)
            
            if prescheduleNotificationLimit < numberOfTasksWithNotifications {
                os_log(.error, "The preschedule notification limit \(self.prescheduleNotificationLimit) is smaller than the numer of tasks with active notifications: \(numberOfTasksWithNotifications)")
                assertionFailure("Please ensure that your preschedule notification limit is bigger than the teasks with active notifications")
            }
            
            let deliveredNotifications = await notificationCenter.deliveredNotifications().sorted(by: { $0.date < $1.date })
            let prescheduleNotificationLimit = max(self.prescheduleNotificationLimit - deliveredNotifications.count, 1)
            
            if prescheduleNotificationLimit < numberOfTasksWithNotifications {
                os_log(.error, "The number of available notification slots is smaller than the numer of tasks with active notifications: \(numberOfTasksWithNotifications), removing the oldest \(numberOfTasksWithNotifications - prescheduleNotificationLimit) notifications.")
                
                let notificationsToBeRemoved = Array(deliveredNotifications
                    .map(\.request.identifier)
                    .filter { identifier in
                        // Only remove notifications that have been scheduled by a task in the Scheduler module:
                        tasks.contains { task in
                            task.contains(scheduledNotificationWithId: identifier)
                        }
                    }
                    .prefix(max(0, numberOfTasksWithNotifications - prescheduleNotificationLimit)))
                
                notificationCenter.removeDeliveredNotifications(withIdentifiers: notificationsToBeRemoved)
            }
            
            let prescheduleNotificationLimitPerTask = prescheduleNotificationLimit / numberOfTasksWithNotifications
            
            for task in self.tasks {
                task.scheduleTaskAndNotification(prescheduleNotificationLimitPerTask)
            }
            
            persistChanges()
        }
    }
}
