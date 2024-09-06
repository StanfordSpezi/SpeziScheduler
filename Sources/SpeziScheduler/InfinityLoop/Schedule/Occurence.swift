//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// A single Occurrence of a Schedule.
///
/// An occurrence of a schedule. Think of it as a single calendar entry of a potentially repeating schedule.
public struct Occurrence {
    /// The start date.
    public let start: Date
    /// The end date.
    public let end: Date
    /// The associated schedule.
    public let schedule: ILSchedule


    init(start: Date, end: Date, schedule: ILSchedule) {
        self.start = start
        self.end = end
        self.schedule = schedule
    }

    init(start: Date, schedule: ILSchedule) {
        let (start, end) = schedule.dates(for: start)

        self.init(start: start, end: end, schedule: schedule)
    }
}


extension Occurrence: Equatable, Sendable {}


extension Occurrence {
    /// Check if the occurrence starts before a given Date.
    ///
    /// - Parameter limit: The exclusive upper bound.
    /// - Returns: Returns `true` if the start date of the occurrence occurs before the `limit`. If the occurrence is an all-day occurrence,
    ///   we return `true` if the the start date is in the same day as the `limit` (still exclusive).
    public func starts(before limit: Date) -> Bool {
        if start < limit {
            return true
        }

        if schedule.duration == .allDay {
            // If schedule specifies all data occurrences, we check if the start date is in the same day as the limit.
            // However, limit is exclusive, so we subtract a second.
            guard let allDayLimit = Calendar.current.date(byAdding: .second, value: -1, to: limit) else {
                preconditionFailure("Failed to subtract 1 second from limit")
            }
            return Calendar.current.isDate(start, inSameDayAs: allDayLimit)
        }

        return false
    }
}


extension Occurrence: Comparable {
    public static func < (lhs: Occurrence, rhs: Occurrence) -> Bool {
        lhs.start < rhs.start
    }
}


extension Occurrence: CustomStringConvertible {
    public var description: String {
        """
        Occurrence(\
        start: \(start), \
        end: \(end)\
        )
        """
    }
}
