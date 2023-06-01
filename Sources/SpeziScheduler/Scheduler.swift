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
import UserNotifications


/// The ``Scheduler/Scheduler`` module allows the scheduling and observation of ``Task``s adhering to a specific ``Schedule``.
///
/// Use the ``Scheduler/Scheduler/init(tasks:)`` initializer or the ``Scheduler/Scheduler/schedule(task:)`` function
/// to schedule tasks that you can obtain using the ``Scheduler/Scheduler/tasks`` property.
/// You can use the ``Scheduler/Scheduler`` as an `ObservableObject` to automatically update your SwiftUI views when new events are emitted or events change.
public class Scheduler<ComponentStandard: Standard, Context: Codable>: Equatable, Module {
    @Dependency private var localStorage: LocalStorage
    
    public private(set) var tasks: [Task<Context>] = []
    private var initialTasks: [Task<Context>]
    private var cancellables: Set<AnyCancellable> = []
    private let taskQueue = DispatchQueue(label: "Scheduler Task Queue", qos: .background)
    
    
    /// Creates a new ``Scheduler`` module.
    /// - Parameter tasks: The initial set of ``Task``s.
    public init(tasks initialTasks: [Task<Context>] = []) {
        self.initialTasks = initialTasks
    }
    
    
    public static func == (lhs: Scheduler<ComponentStandard, Context>, rhs: Scheduler<ComponentStandard, Context>) -> Bool {
        lhs.tasks == rhs.tasks
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
    }
    
    
    public func requestLocalNotificationAuthorization() async throws {
        if await UNUserNotificationCenter.current().notificationSettings().authorizationStatus != .authorized {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
        
        taskQueue.async {
            for task in self.tasks {
                task.scheduleTaskAndNotification()
            }
        }
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
        
        taskQueue.async {
            task.scheduleTaskAndNotification()
            RunLoop.current.run()
        }
        
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
    
    
    deinit {
        for cancellable in cancellables {
            cancellable.cancel()
        }
    }
}
