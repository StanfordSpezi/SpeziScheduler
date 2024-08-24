//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftData

// TODO: there are two concepts (ending a task vs. deleting a task (with all of its previous versions)?)


@Model
public final class ILTask {
    #Unique<ILTask>([\.id, \.effectiveFrom, \.nextVersion])

    /// The identifier for this task.
    ///
    /// This is a identifier for this task (e.g., `"social-support-questionnaire"`).
    public private(set) var id: String
    /// The user-visible title for this task.
    public var title: String // TODO: both optional! would love LocalizedStringResource (however, cannot persist in SwiftData!)
    /// Instructions for this task.
    ///
    /// Instructions might describe the purpose for this task.
    public var instructions: String

    // TODO: when updating a schedule, we must make sure that we do not shadow outcomes that have already been created for
    //  occurrences that would be overwritten!

    /// The schedule for the events of this Task.
    public var schedule: ILSchedule

    // TODO: the relationship makes us require querying all outcomes always!
    /// The list of outcomes associated with this Task.
    @Relationship(deleteRule: .cascade, inverse: \Outcome.task)
    public private(set) var outcomes: [Outcome]

    /// The date from which is version of the task is effective.
    public private(set) var effectiveFrom: Date

    /// A reference to a previous version of this task.
    ///
    /// The ``effectiveFrom`` date specifies when the previous task is considered outdated and
    /// is replaced by this task.
    @Relationship(inverse: \ILTask.nextVersion)
    public private(set) var previousVersion: ILTask?
    /// A reference to a new version of this task.
    ///
    /// If not `nil`, this reference specifies the next version of this task.
    @Relationship(deleteRule: .deny)
    public private(set) var nextVersion: ILTask?

    // TODO: additional context? => outcome values (e.g., goals for e.g. rings or just task like questionnaires)
    // TODO: notifications

    public init(
        id: String,
        title: String,
        instructions: String,
        schedule: ILSchedule,
        effectiveFrom: Date = .now
    ) {
        self.id = id
        self.title = title
        self.instructions = instructions
        self.schedule = schedule
        self.outcomes = []
        self.effectiveFrom = effectiveFrom
    }

    func addOutcome(_ outcome: Outcome) {
        // TODO: does it automatically set the inverse property?
        outcomes.append(outcome) // automatically saves the outcome to the container
    }

    // TODO: easy startup operation would be; getOrCreate -> updateIfNotCurrent!
    public func createUpdatedVersion(
        title: String? = nil, // TODO: doesn't support deleting the title (if we make it optional)
        instructions: String? = nil,
        schedule: ILSchedule? = nil,
        effectiveFrom: Date = .now
    ) -> ILTask {
        guard title != nil || instructions != nil || schedule != nil else {
            // TODO: check if there is actually any equatable difference!
            return self
        }

        // TODO: update might incur data loss?
        /*
         // Ensure that new versions of tasks do not overwrite regions of previous
         // versions that already have outcomes saved to them.
         //
         // |<------------- Time Line --------------->|
         //  TaskV1 ------x------------------->
         //                     V2 ---------->
         //              V3------------------>
         //
         // Throws an error when updating to V3 from V2 if V1 has outcomes after `x`.
         // Throws an error when updating to V3 from V2 if V2 has any outcomes.
         // Does not throw when updating to V3 from V2 if V1 has outcomes before `x`.
         */

        let newVersion = ILTask(
            id: id,
            title: title ?? self.title,
            instructions: instructions ?? self.instructions,
            schedule: schedule ?? self.schedule,
            effectiveFrom: effectiveFrom
        )

        // TODO: just check equatability?

        nextVersion = newVersion
        // TODO: do i need to set the previous version?
        return newVersion
    }
}
