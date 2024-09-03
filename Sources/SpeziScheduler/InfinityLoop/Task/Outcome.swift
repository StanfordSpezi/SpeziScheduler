//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation
import SwiftData


/// The outcome of an event.
///
/// Describes a  outcomes of an ``Event`` of a ``Task``.
@Model
public final class Outcome {
    #Index<Outcome>([\.id, \.occurrenceStartDate])

    /// The id of the outcome.
    @Attribute(.unique)
    public var id: UUID

    /// The completion date of the outcome.
    public private(set) var completionDate: Date
    /// The date of the occurrence.
    ///
    /// We use the occurrence date to match the outcome to the ``Occurrence`` instance.
    /// `Date` is independent of any specific calendar or time zone, representing a time interval relative to an absolute reference date.
    /// Therefore, you can think of this property as an occurrence index that is monotonic but not necessarily continuous.
    private(set) var occurrenceStartDate: Date

    /// The associated task of the outcome.
    public private(set) var task: ILTask

    /// The occurrence of the event the outcome is associated with.
    public var occurrence: Occurrence {
        // correct would probably be to call `task.schedule.occurrence(forStartDate:)` and check if this still exists
        // but assuming the occurrence exists and having a non-optional return type is just easier
        Occurrence(start: occurrenceStartDate, schedule: task.schedule)
    }

    /// The associated event for this outcome.
    public var event: ILEvent {
        ILEvent(task: task, occurrence: occurrence, outcome: self)
    }

    /// Additional userInfo stored alongside the outcome.
    private var userInfo = UserInfoStorage<OutcomeAnchor>()

    init(task: ILTask, occurrence: Occurrence) {
        self.id = UUID()
        self.completionDate = .now
        self.task = task
        self.occurrenceStartDate = occurrence.start
    }
}


extension Outcome {
    public subscript<Source: UserInfoKey<OutcomeAnchor>>(_ source: Source.Type) -> Source.Value? {
        get {
            userInfo.get(source)
        }
        set {
            userInfo.set(source, value: newValue)
        }
    }
}


extension Occurrence: Comparable {
    public static func < (lhs: Occurrence, rhs: Occurrence) -> Bool {
        lhs.start < rhs.start
    }
}
