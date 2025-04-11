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
/// - Note: Events are not auto-updating. If you have multiple `Event` instances referring to the same ``Occurrence`` of the same ``Task``
/// (e.g., obtained from multiple calls to ``Scheduler/queryEvents(for:in:)``), completing one of them will not cause the other ones to get updated.
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
/// - ``complete(ignoreCompletionPolicy:with:)``
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
    public var isCompleted: Bool {
        outcome != nil
    }
    
    /// :nodoc:
    @available(*, deprecated, renamed: "isCompleted")
    public var completed: Bool { isCompleted }
    
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
}


extension Event {
    public enum CompletionError: Error {
        /// The event's ``AllowedCompletionPolicy`` doesn't allow completing the event at this time.
        case preventedByCompletionPolicy
    }
    
    
    /// Complete the event.
    ///
    /// It the event is already completed, this will have no effect.
    ///
    /// - Warning: This function will ignore the underlying task's ``Task/completionPolicy``.
    @available(*, deprecated, renamed: "complete(ignoreCompletionPolicy:with:)")
    @MainActor
    @discardableResult
    @_disfavoredOverload
    public func complete() -> Outcome {
        do {
            return try complete(ignoreCompletionPolicy: true)
        } catch {
            // if the completion policy is ignored, complete will not throw.
            preconditionFailure("Unreachable")
        }
    }
    
    /// Complete the event with additional information.
    ///
    /// - parameter ignoreCompletionPolicy: Allows for forced completion of the event, even if the underlying task's ``AllowedCompletionPolicy`` would otherwise prohibit it. Defaults to `false`.
    /// - parameter closure: A closure that allows setting properties of the outcome.
    ///
    /// ```swift
    /// event.complete { outcome in
    ///     outcome.myCustomData = "..."
    /// }
    /// ```
    ///
    /// - Warning: If the event is already completed, the closure will be applied to the existing outcome.
    @MainActor
    @discardableResult
    public func complete(
        ignoreCompletionPolicy: Bool = false,
        with closure: (Outcome) -> Void = { _ in }
    ) throws(CompletionError) -> Outcome {
        guard ignoreCompletionPolicy || task.completionPolicy.isAllowedToComplete(event: self) else {
            throw .preventedByCompletionPolicy
        }
        switch outcomeState.outcome {
        case let .createWith(scheduler):
            let outcome = createNewOutcome(with: closure)
            // Makes sure this is saved instantly. Only after models are fully saved, they are made available in the `outcomes`
            // property of the task. Also saving makes sure an @EventQuery would be instantly refreshed.
            scheduler.addOutcome(outcome)
            return outcome
        case let .value(outcome):
            // allows to merge additional properties
            closure(outcome)
            return outcome
        case .mocked:
            return createNewOutcome(with: closure)
        case .preventCreation:
            preconditionFailure("Tried to complete an event that has an incomplete representation: \(self)")
        }
    }

    private func createNewOutcome(with closure: (Outcome) -> Void) -> Outcome {
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
