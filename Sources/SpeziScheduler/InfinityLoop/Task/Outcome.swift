//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftData


/// The outcome of an event.
///
/// Describes a  outcomes of an ``Event`` of a ``Task``.
@Model
public final class Outcome {
    #Index([\Outcome.id])

    /// The id of the outcome.
    @Attribute(.unique)
    public var id: UUID

    /// The completion date of the outcome.
    public private(set) var completionDate: Date

    /// The associated task of the outcome.
    public private(set) var task: ILTask? // TODO: we might be able to make this non-optional?
    private var occurrenceIndex: Int // TODO: to which version of the task does this occurrence index point?

    public var occurrence: Occurrence? {
        task?.schedule.occurrence(forIndex: occurrenceIndex)
    }

    // TODO: have a getter for the Event?

    // TODO: custom storage for outcomes?

    init(occurrenceIndex: Int) {
        self.id = UUID()
        self.completionDate = .now
        self.occurrenceIndex = occurrenceIndex

        // TODO: task and associate outcome?
    }
}
