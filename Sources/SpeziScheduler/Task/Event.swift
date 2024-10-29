//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// Describes a single event of a Task.
///
/// ## Topics
///
/// ### Properties
/// - ``occurrence``
/// - ``task``
/// - ``outcome``
/// - ``completed``
///
/// ### Completing an Event
/// - ``complete()``
/// - ``complete(with:)``
@DebugDescription
public struct Event {
    /// The outcome value.
    @_spi(Internal)
    public enum OutcomeValue {
        /// Create outcome with the associated scheduler instance.
        case createWith(Scheduler)
        /// Outcome value.
        case value(Outcome)
        /// For testing support to avoid associating a scheduler.
        case mocked
        /// Cannot create new outcomes with this instance of event.
        case preventCreation

        var value: Outcome? {
            switch self {
            case let .value(value):
                value
            case .createWith, .mocked, .preventCreation:
                nil
            }
        }
    }

    @Observable
    fileprivate class State {
        var outcome: OutcomeValue

        init(_ outcome: OutcomeValue) {
            self.outcome = outcome
        }
    }

    /// The task the event is associated with.
    public let task: Task
    /// Information about when this event occurs.
    public let occurrence: Occurrence

    private let outcomeState: State


    /// The outcome of the event if already completed.
    public var outcome: Outcome? {
        if let outcome = outcomeState.outcome.value {
            outcome
        } else {
            nil
        }
    }

    /// Determine if the event was completed.
    ///
    /// Completed events have an outcome.
    public var completed: Bool {
        outcome != nil
    }
    
    /// Create new event.
    /// - Parameters:
    ///   - task: The task instance.
    ///   - occurrence: The occurrence description.
    ///   - outcome: The internal outcome value.
    @_spi(Internal)
    public init(task: Task, occurrence: Occurrence, outcome: OutcomeValue) {
        self.task = task
        self.occurrence = occurrence
        self.outcomeState = State(outcome)
    }

    /// Complete the event.
    ///
    /// Does nothing if the event is already completed.
    @MainActor
    @discardableResult
    public func complete() -> Outcome {
        self.complete { _ in }
    }
    
    /// Complete the event with additional information.
    ///
    /// ```swift
    /// var event: Event
    ///
    /// event.complete {
    ///     event.myCustomData = "..."
    /// }
    /// ```
    ///
    /// - Warning: If the event is already completed, the closure will be applied to the existing outcome.
    ///
    /// - Parameter closure: A closure that allows setting properties of the outcome.
    @MainActor
    @discardableResult
    public func complete(with closure: (Outcome) -> Void) -> Outcome {
        switch outcomeState.outcome {
        case let .createWith(scheduler):
            let outcome = createNewOutCome(with: closure)

            // Makes sure this is saved instantly. Only after models are fully saved, they are made available in the `outcomes`
            // property of the task. Also saving makes sure an @EventQuery would be instantly refreshed.
            scheduler.addOutcome(outcome)

            return outcome
        case let .value(outcome):
            // allows to merge additional properties
            closure(outcome)
            return outcome
        case .mocked:
            return createNewOutCome(with: closure)
        case .preventCreation:
            preconditionFailure("Tried to complete an event that has an incomplete representation: \(self)")
        }
    }

    private func createNewOutCome(with closure: (Outcome) -> Void) -> Outcome {
        let outcome = Outcome(task: task, occurrence: occurrence)
        closure(outcome)
        self.outcomeState.outcome = .value(outcome)

        return outcome
    }
}


extension Event: Identifiable {
    public struct ID {
        private let taskId: Task.ID
        private let occurrenceData: Date

        fileprivate init(taskId: Task.ID, occurrenceData: Date) {
            self.taskId = taskId
            self.occurrenceData = occurrenceData
        }
    }

    public var id: ID {
        ID(taskId: task.id, occurrenceData: occurrence.start)
    }
}


extension Event.ID: Hashable, Sendable {}


extension Event: CustomStringConvertible {
    public var description: String {
        """
        Event(\
        occurrence: \(occurrence), \
        task: \(task), \
        outcome: \(outcomeState.outcome.value.map { $0.description } ?? "nil")\
        )
        """
    }
}
