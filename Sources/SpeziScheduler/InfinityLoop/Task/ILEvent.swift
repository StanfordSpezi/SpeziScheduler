//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


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

    /// Complete the event with an outcome.
    ///
    /// - Parameter outcome: The outcome that completes the event.
    public mutating func setOutcome(_ outcome: Outcome) { // TODO: simple "Void" completion?
        self.outcome = outcome
        task.addOutcome(outcome)
    }
}
