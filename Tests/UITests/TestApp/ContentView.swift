//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziScheduler
import SwiftUI


struct ContentView: View {
    @EnvironmentObject private var scheduler: TestAppScheduler
    @State private var notificationAuthorizationGranted: Bool = false
    
    
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
            scheduler.schedule(
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
        Button("Add Notification Task") {
            let currentDate = Date.now
            let hour = Calendar.current.component(.hour, from: currentDate)
            // We expect the UI test to take at least 20 seconds to mavigate out of the app and to the home screen.
            // We then trigger the task in the minute after that, the UI test needs to wait at least one minute.
            let minute = Calendar.current.component(.minute, from: currentDate.addingTimeInterval(20)) + 1
            
            // We schedule 128 notifications to test that the schedule limit to 64 notifications per device is enforced
            // and notifications show on the device (iOS only limits up to 64 scheduled local notifications.
            scheduler.schedule(
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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
