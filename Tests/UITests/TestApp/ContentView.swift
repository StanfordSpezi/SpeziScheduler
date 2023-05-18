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
    
    
    private var tasks: Int {
        scheduler.tasks.count
    }
    
    private var events: Int {
        scheduler.tasks
            .flatMap { $0.events() }
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
        Text("Fulfilled \(fulfilledEvents) Events")
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
