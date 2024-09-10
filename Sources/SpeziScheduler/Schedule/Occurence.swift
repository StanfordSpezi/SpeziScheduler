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
///
/// ## Topics
///
/// ### Properties
/// - ``start``
/// - ``end``
/// - ``schedule``
public struct Occurrence {
    /// The start date.
    public let start: Date
    /// The end date.
    public let end: Date
    /// The associated schedule.
    public let schedule: Schedule


    init(start: Date, end: Date, schedule: Schedule) {
        self.start = start
        self.end = end
        self.schedule = schedule
    }

    init(start: Date, schedule: Schedule) {
        let (start, end) = schedule.dates(for: start)

        self.init(start: start, end: end, schedule: schedule)
    }
}


extension Occurrence: Equatable, Sendable {}


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
