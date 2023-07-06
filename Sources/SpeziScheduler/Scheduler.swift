//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Combine
import Foundation
import Spezi
import SpeziLocalStorage
import UIKit
import UserNotifications


/// The ``Scheduler/Scheduler`` module allows the scheduling and observation of ``Task``s adhering to a specific ``Schedule``.
///
/// Use the ``Scheduler/Scheduler/init(tasks:)`` initializer or the ``Scheduler/Scheduler/schedule(task:)`` function
/// to schedule tasks that you can obtain using the ``Scheduler/Scheduler/tasks`` property.
/// You can use the ``Scheduler/Scheduler`` as an `ObservableObject` to automatically update your SwiftUI views when new events are emitted or events change.
public class Scheduler<ComponentStandard: Standard, Context: Codable>: NSObject, UNUserNotificationCenterDelegate, Module {
    @Dependency private var localStorage: LocalStorage
    
    @Published public private(set) var tasks: [Task<Context>] = []
    private var initialTasks: [Task<Context>]
    private var cancellables: Set<AnyCancellable> = []
    
    /// Indicates whether the necessary authorization to deliver local notifications is already granted.
    public var localNotificationAuthorization: Bool {
        get async {
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized
        }
    }
    
    /// Creates a new ``Scheduler`` module.
    /// - Parameter tasks: The initial set of ``Task``s.
    public init(tasks initialTasks: [Task<Context>] = []) {
        self.initialTasks = initialTasks
    }
    
    
    public func configure() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(timeZoneChanged),
            name: Notification.Name.NSSystemTimeZoneDidChange,
            object: nil
        )
        
        self.objectWillChange
            .sink {
                _Concurrency.Task {
                    do {
                        try self.localStorage.store(self.tasks)
                    } catch {
                        print(error)
                    }
                }
            }
            .store(in: &cancellables)
        
        
        guard let storedTasks = try? localStorage.read([Task<Context>].self) else {
            schedule(tasks: initialTasks)
            return
        }
        
        schedule(tasks: storedTasks)
        
        // Schedule tasks with a timer and make sure that we always schedule the next 16 tasks.
        updateScheduleTaskAndNotifications()
    }
    
    
    /// Presents the system authentication UI to send local notifications if the application is not yet permitted to send local notifications.
    public func requestLocalNotificationAuthorization() async throws {
        if await !localNotificationAuthorization {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            
            // Triggers an update of the UI in case the notification permissions are changed
            _Concurrency.Task { @MainActor in
                self.objectWillChange.send()
            }
        }
        
        updateScheduleTaskAndNotifications()
    }
    
    public func willFinishLaunchingWithOptions(_ application: UIApplication, launchOptions: [UIApplication.LaunchOptionsKey: Any]) {
        UNUserNotificationCenter.current().delegate = self
    }
    
    @MainActor
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        self.objectWillChange.send()
    }
    
    @MainActor
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        self.objectWillChange.send()
        return [.badge, .banner, .sound]
    }
    
    @MainActor
    public func sceneWillEnterForeground(_ scene: UIScene) {
        self.objectWillChange.send()
    }
    
    
    /// Schedule a new ``Task`` in the ``Scheduler`` module.
    /// - Parameter task: The new ``Task`` instance that should be scheduled.
    public func schedule(task: Task<Context>) {
        task.objectWillChange
            .receive(on: RunLoop.main)
            .sink {
                self.objectWillChange.send()
                self.updateScheduleTaskAndNotifications()
            }
            .store(in: &cancellables)
        
        task.scheduleTaskAndNotification()
        
        tasks.append(task)
    }
    
    
    @objc
    private func timeZoneChanged() async {
        _Concurrency.Task { @MainActor in
            self.objectWillChange.send()
        }
    }
    
    private func schedule(tasks: [Task<Context>]) {
        self.tasks.reserveCapacity(self.tasks.count + tasks.count)
        for task in tasks {
            schedule(task: task)
        }
    }
    
    private func updateScheduleTaskAndNotifications() {
        let numberOfTasksWithNotifications = max(tasks.filter(\.notifications).count, 1)
        let prescheduleLimit = 64 / numberOfTasksWithNotifications
        
        for task in self.tasks {
            task.scheduleTaskAndNotification(prescheduleLimit)
        }
    }
    
    
    deinit {
        for cancellable in cancellables {
            cancellable.cancel()
        }
    }
}
