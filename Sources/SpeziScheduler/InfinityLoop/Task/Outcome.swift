//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftData


@Model
public final class Outcome {
    #Index([\Outcome.id])

    /// The id of the outcome.
    @Attribute(.unique)
    public var id: UUID

    /// The completion date of the outcome.
    public private(set) var completionDate: Date

    /// The associated task of the outcome.
    public private(set) var task: ILTask? // TODO: the 
    private var occurrenceIndex: Int // TODO: to which version of the task does this occurrence index point?

    public var occurrence: Occurrence? {
        // TODO: task?.schedule.ocr
        task?.schedule.occurrences(forIndex: occurrenceIndex)
    }
    // TODO: the index of the occurence (= event)

    // TODO: custom storage for outcomes?

    init(occurrenceIndex: Int) {
        self.id = UUID()
        self.completionDate = .now
        self.occurrenceIndex = occurrenceIndex

        // TODO: task and associate outcome?
    }
}
