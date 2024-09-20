//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


struct TaskNextOccurrenceCache {
    struct Entry {
        let occurrence: Occurrence?
    }

    private let range: PartialRangeFrom<Date>
    private var cache: [String: Entry] = [:]

    init(in range: PartialRangeFrom<Date>) {
        self.range = range
    }

    subscript(_ task: Task) -> Occurrence? {
        mutating get {
            if let entry = cache[task.id] {
                return entry.occurrence
            }

            let occurrence = task.schedule.nextOccurrence(in: range)
            cache[task.id] = Entry(occurrence: occurrence)
            return occurrence
        }
    }
}
