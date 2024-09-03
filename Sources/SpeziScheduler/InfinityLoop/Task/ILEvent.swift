//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// Describes a single event of a Task.
public struct ILEvent {
    /// The task the event is associated with.
    public let task: ILTask
    /// Information about when this event occurs.
    public let occurrence: Occurrence

    /// The outcome of the event if already completed.
    public private(set) var outcome: Outcome?

    /// Determine if the event was completed.
    ///
    /// Completed events have an outcome.
    public var completed: Bool {
        outcome != nil
    }

    init(task: ILTask, occurrence: Occurrence, outcome: Outcome?) {
        self.task = task
        self.occurrence = occurrence
        self.outcome = outcome
    }

    /// Complete the event.
    public mutating func complete() {
        self.complete { _ in }
    }
    
    /// Complete the event with additional information.
    ///
    /// ```swift
    /// var event: ILEvent
    ///
    /// event.complete {
    ///     event.myCustomData = "..."
    /// }
    /// ```
    ///
    /// - Parameter closure: A closure that allows setting properties of the outcome.
    public mutating func complete(with closure: (Outcome) -> Void) {
        let outcome = Outcome(task: task, occurrence: occurrence)
        closure(outcome)
        self.outcome = outcome
        task.addOutcome(outcome) // TODO: is this necessary? Would this duplicate the entry?
    }
}


extension ILEvent: Identifiable {
    public struct ID {
        private let taskId: ILTask.ID
        private let occurrenceData: Date

        fileprivate init(taskId: ILTask.ID, occurrenceData: Date) {
            self.taskId = taskId
            self.occurrenceData = occurrenceData
        }
    }

    public var id: ID {
        ID(taskId: task.id, occurrenceData: occurrence.start)
    }
}


extension ILEvent.ID: Hashable, Sendable {}
