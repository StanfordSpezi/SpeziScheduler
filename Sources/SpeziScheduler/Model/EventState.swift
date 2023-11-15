//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// State of an `Event`.
public enum EventState: Equatable, Hashable, CustomStringConvertible, Codable {
    /// The event is scheduled at the given `Date`.
    case scheduled(at: Date)
    /// The event is overdue since the given `Date`.
    case overdue(since: Date)
    /// The event was completed and originally scheduled at the given `Date`s.
    case completed(at: Date, scheduled: Date)

    var scheduledAt: Date {
        switch self {
        case let .scheduled(at):
            return at
        case let .overdue(since):
            return since
        case let .completed(_, scheduled):
            return scheduled
        }
    }

    public var description: String {
        switch self {
        case let .scheduled(at):
            return "scheduled(at: \(at.description))"
        case let.overdue(since):
            return "overdue(since: \(since.description))"
        case let.completed(at, scheduled):
            return "completed(at: \(at.description), scheduled: \(scheduled.description))"
        }
    }
}
