//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Combine
import SwiftData
import SwiftUI


@propertyWrapper
@MainActor
public struct EventQuery {
    public struct Configuration {
        fileprivate let range: Range<Date>
        fileprivate let taskPredicate: Predicate<ILTask>

        public fileprivate(set) var fetchError: (any Error)?

        init(range: Range<Date>, taskPredicate: Predicate<ILTask>) {
            self.range = range
            self.taskPredicate = taskPredicate
        }
    }


    @Environment(ILScheduler.self)
    private var scheduler

    @State private var viewUpdate: UInt64 = 0
    @State private var cancelable: AnyCancellable?

    @State private var configuration: Configuration
    @State private var fetchedEvents: [ILEvent] = []

    public var wrappedValue: [ILEvent] {
        fetchedEvents
    }

    public var projectedValue: Configuration {
        configuration
    }

    public init(
        in range: Range<Date>, // TODO: eventually support closed date range?
        predicate: Predicate<ILTask> = #Predicate { _ in true }
    ) {
        self.configuration = Configuration(range: range, taskPredicate: predicate)
    }
}


extension EventQuery: DynamicProperty {
    public mutating nonisolated func update() {
        MainActor.assumeIsolated { // TODO: this is not great, `update()` is public!
            doUpdate()
        }
    }

    private mutating func doUpdate() {
        guard let context = try? scheduler.context else { // TODO: just embed this into the Scheduler?
            configuration.fetchError = ILScheduler.DataError.invalidContainer
            return
        }

        if cancelable != nil {
            let viewUpdate = $viewUpdate
            cancelable = NotificationCenter.default.publisher(for: ModelContext.didSave, object: context)
                .sink { _ in
                    // we are using the Main Context, that always runs on the Main Actor
                    // TODO: this is implementation details (make sure it doesnt change)
                    MainActor.assumeIsolated {
                        viewUpdate.wrappedValue &+= 1 // increment that automatically wraps around
                    }
                }
        }

        do {
            // TODO: should this run on the main thread?
            fetchedEvents = try scheduler.queryEvents(for: configuration.range, predicate: configuration.taskPredicate)
        } catch {
            configuration.fetchError = error
        }
    }
}
