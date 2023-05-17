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


/// The ``Scheduler/Scheduler`` module allows the scheduling and observation of ``Task``s adhering to a specific ``Schedule``.
///
/// Use the ``Scheduler/Scheduler/init(tasks:)`` initializer or the ``Scheduler/Scheduler/schedule(task:)`` function
/// to schedule tasks that you can obtain using the ``Scheduler/Scheduler/tasks`` property.
/// You can use the ``Scheduler/Scheduler`` as an `ObservableObject` to automatically update your SwiftUI views when new events are emitted or events change.
public class Scheduler<ComponentStandard: Standard, Context: Codable>: Equatable, Module {
    @Dependency private var localStorage: LocalStorage
    
    public private(set) var tasks: [Task<Context>] = []
    private var initialTasks: [Task<Context>]
    private var timers: [Timer] = []
    private var cancellables: Set<AnyCancellable> = []
    
    
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
    
    
    /// Schedule a new ``Task`` in the ``Scheduler`` module.
    /// - Parameter task: The new ``Task`` instance that should be scheduled.
    public func schedule(task: Task<Context>) {
        DispatchQueue.global(qos: .background).async {
            let futureEvents = task.events(from: .now.addingTimeInterval(-1), to: .endDate(.distantFuture))
            self.timers.reserveCapacity(self.timers.count + futureEvents.count)
            
            for futureEvent in futureEvents {
                let scheduledTimer = Timer(
                    timeInterval: max(Date.now.distance(to: futureEvent.scheduledAt), TimeInterval.leastNonzeroMagnitude),
                    repeats: false,
                    block: { timer in
                        timer.invalidate()
                        task.objectWillChange.send()
                    }
                )
                
                RunLoop.current.add(scheduledTimer, forMode: .common)
                self.timers.append(scheduledTimer)
            }
            
            RunLoop.current.run()
        }
        
        task.objectWillChange
            .receive(on: RunLoop.main)
            .sink {
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
        
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
        for timer in timers where timer.isValid {
            timer.invalidate()
        }
        for cancellable in cancellables {
            cancellable.cancel()
        }
    }
}
