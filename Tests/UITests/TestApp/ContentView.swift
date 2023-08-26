//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@testable import SpeziScheduler
import SwiftUI


struct ContentView: View {
    struct EventLog: Identifiable, Comparable {
        static func < (lhs: ContentView.EventLog, rhs: ContentView.EventLog) -> Bool {
            lhs.id < rhs.id
        }
        
        
        let id: Date
        let log: String
    }
    
    
    @EnvironmentObject private var scheduler: TestAppScheduler
    @State private var notificationAuthorizationGranted = false
    
    
    private var tasks: Int {
        scheduler.tasks.count
    }
    
    private var events: Int {
        scheduler.tasks
            .flatMap { $0.events() }
            .count
    }
    
    private var pastEvents: Int {
        scheduler.tasks
            .flatMap { $0.events(to: .endDate(.now)) }
            .count
    }
    
    private var fulfilledEvents: Int {
        scheduler.tasks
            .flatMap { $0.events() }
            .filter { $0.complete }
            .count
    }
    
    private var eventLogs: [EventLog] {
        scheduler.tasks
            .flatMap { $0.events() }
            .compactMap { event in
                guard let log = event.log else {
                    return nil
                }
                
                return EventLog(id: event.scheduledAt, log: log)
            }
            .sorted()
    }
    
    
    var body: some View {
        Text("Scheduler")
            .font(.headline)
        Text("\(tasks) Tasks")
        Text("\(events) Events")
        Text("\(pastEvents) Past Events")
        Text("Fulfilled \(fulfilledEvents) Events")
        Button("Request Notification Permissions") {
            _Concurrency.Task {
                try await scheduler.requestLocalNotificationAuthorization()
                notificationAuthorizationGranted = await scheduler.localNotificationAuthorization
            }
        }
            .disabled(notificationAuthorizationGranted)
        Button("Add Task") {
            _Concurrency.Task {
                await scheduler.schedule(
                    task: Task(
                        title: "New Task",
                        description: "New Task",
                        schedule: Schedule(
                            start: .now,
                            repetition: .matching(.init(nanosecond: 0)), // Every full second
                            end: .numberOfEvents(2)
                        ),
                        context: "New Task!"
                    )
                )
            }
        }
        Button("Add Notification Task") {
            _Concurrency.Task {
                let currentDate = Date.now
                let hour = Calendar.current.component(.hour, from: currentDate)
                // We expect the UI test to take at least 20 seconds to mavigate out of the app and to the home screen.
                // We then trigger the task in the minute after that, the UI test needs to wait at least one minute.
                let minute = Calendar.current.component(.minute, from: currentDate.addingTimeInterval(20)) + 1
                
                // We schedule 128 notifications to test that the schedule limit to 64 notifications per device is enforced
                // and notifications show on the device (iOS only limits up to 64 scheduled local notifications.
                await scheduler.schedule(
                    task: Task(
                        title: "Notification Task",
                        description: "Notification Task",
                        schedule: Schedule(
                            start: .now,
                            repetition: .matching(.init(hour: hour, minute: minute)),
                            end: .numberOfEvents(128)
                        ),
                        notifications: true,
                        context: "Notification Task!"
                    )
                )
            }
        }
        Button("Fulfill Event") {
            guard let uncompletedEvent = scheduler.tasks
                .flatMap({ $0.events() })
                .first(where: { !$0.complete }) else {
                return
            }
            _Concurrency.Task {
                await uncompletedEvent.complete(true)
            }
        }
        Button("Unfulfull Event") {
            guard let completedEvent = scheduler.tasks
                .flatMap({ $0.events() })
                .first(where: { $0.complete }) else {
                return
            }
            _Concurrency.Task {
                await completedEvent.complete(false)
            }
        }
        ScrollView {
            ForEach(eventLogs) { eventLog in
                Text(eventLog.log)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
