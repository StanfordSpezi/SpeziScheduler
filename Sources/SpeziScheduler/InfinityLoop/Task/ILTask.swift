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
class TaskDraft {
    var effectiveFrom: Date
    var supersededOn: Date? // TODO: if nil, there is no  new task?


    @Relationship(inverse: \TaskDraft.superSeededBy)
    var superSeeds: TaskDraft?
    var superSeededBy: TaskDraft?

    init(effectiveFrom: Date, supersededOn: Date?, superSeeds: TaskDraft?, superSeededBy: TaskDraft?) {
        self.effectiveFrom = effectiveFrom
        self.supersededOn = supersededOn
        self.superSeeds = superSeeds
        self.superSeededBy = superSeededBy
    }
}


@Model
final class NewTask {
    // TODO: the problem here, it always fetches ALL previous versions? => NOOO
    /*
     SwiftData lazily loads all relationship data, fetching it only when accessed by your object.
     If you know the relationship will be used immediately, you should create a fetch descriptor with its relationshipKeyPathsForPrefetching
     set to the relationships you'll use.
     */
    // TODO: No no, we can prefetch, but we can only prefetch ALL versions of a task!

    @Relationship(deleteRule: .cascade)
    var current: TaskVersion
    @Relationship(deleteRule: .cascade)
    var previousVersions: [TaskVersion] // TODO: might be empty

    var title: String { // TODO: similar overloads!
        current.title
    }
    // TODO: short hand versions to get all events for a given time interval!

    init(
        id: String,
        title: String,
        instructions: String,
        schedule: ILSchedule,
        effectiveFrom: Date = .now
    ) {
        self.current = TaskVersion(title: title, instruction: instructions, schedule: schedule, effectiveFrom: effectiveFrom)
        self.previousVersions = []
    }
}


@Model
final class TaskVersion {
    private(set) var id: UUID

    private(set) var title: String
    private(set) var instruction: String
    private(set) var schedule: ILSchedule
    private(set) var effectiveFrom: Date

    init(id: UUID = UUID(), title: String, instruction: String, schedule: ILSchedule, effectiveFrom: Date) {
        self.id = id
        self.title = title
        self.instruction = instruction
        self.schedule = schedule
        self.effectiveFrom = effectiveFrom
    }
}


@Model
public final class ILTask {
    #Unique<ILTask>([\.id, \.effectiveFrom, \.effectiveTo])

    public private(set) var id: String
    public var title: String
    public var instructions: String

    // TODO: when updating a schedule, we must make sure that we do not shadow outcomes that have already been created for
    //  occurrences that would be overwritten!
    public var schedule: ILSchedule

    // TODO: the relationship makes us require querying all outcomes always!
    @Relationship(deleteRule: .cascade, inverse: \Outcome.task)
    public private(set) var outcomes: [Outcome]

    public private(set) var effectiveFrom: Date
    /// The date until which this task is effective.
    private(set) var effectiveTo: Date?

    @Relationship(inverse: \ILTask.nextVersion)
    public private(set) var previousVersion: ILTask?
    @Relationship(deleteRule: .deny)
    public private(set) var nextVersion: ILTask?

    // TODO: notifications
    // TODO: additional context? => outcome values (e.g., goals for e.g. rings or just task like questionnaires)

    init(
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

        updateEffectiveTo()

        // TODO: should also happen in the other initializer (inconsistency from the database :()
    }

    private func updateEffectiveTo() {
        let end = schedule.end
        let nextEffectiveFrom = nextVersion?.effectiveFrom

        effectiveTo = if let end, let nextEffectiveFrom {
            min(end, nextEffectiveFrom)
        } else if let end {
            end
        } else if let nextEffectiveFrom {
            nextEffectiveFrom
        } else {
            nil
        }
    }

    func addOutcome(_ outcome: Outcome) {
        // TODO: does it automatically set the inverse property?
        outcomes.append(outcome) // automatically saves the outcome to the container
    }

    // TODO: easy startup operation would be; getOrCreate -> updateIfNotCurrent!
    public func createUpdatedVersion(
        title: String? = nil,
        instructions: String? = nil,
        schedule: ILSchedule? = nil,
        effectiveFrom: Date = .now
    ) -> ILTask {
        guard title != nil || instructions != nil || schedule != nil else {
            // TODO: check if there is actually any equatable difference!
            return self
        }

        // TODO: update might incurr data loss?
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
