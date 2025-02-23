//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// Policy to decide when an event is allowed to be completed.
public enum AllowedCompletionPolicy: Hashable, Sendable, Codable {
    /// The event is allowed to completed if the event is occurring today.
    case sameDay
    /// The event is allowed to be completed if the date is after the start date and time.
    case afterStart
    /// The event is allowed to be completed if the date is after the start date and time but is still occurring today.
    case sameDayAfterStart
    /// The event is only allowed to completed while it is occurring.
    case duringEvent
}


extension AllowedCompletionPolicy {
    /// Determine if an event is currently allowed to be completed.
    /// - Parameters:
    ///   - event: The event.
    ///   - date: The date that is considered as the `now` date.
    /// - Returns: `true` if the event is currently allowed to be completed. `false` otherwise. If the date at which the event is allowed to be completed is still in the future,
    ///     you can use the ``dateOnceCompletionIsAllowed(for:now:)`` and ``dateOnceCompletionBecomesDisallowed(for:now:)`` methods to retrieve the time
    ///     when you need to update your UI.
    public func isAllowedToComplete(event: Event, now date: Date = .now) -> Bool {
        switch self {
        case .sameDay:
            Calendar.current.isDateInToday(date)
        case .afterStart:
            date >= event.occurrence.start
        case .sameDayAfterStart:
            Calendar.current.isDateInToday(date) && date >= event.occurrence.start
        case .duringEvent:
            (event.occurrence.start..<event.occurrence.end).contains(date)
        }
    }
    
    /// Retrieve the date at which the result of `isAllowedToComplete` changes to allowed.
    /// - Parameters:
    ///   - event: The event.
    ///   - date: The date that is considered as the `now` date.
    /// - Returns: Returns the date at which the event is allowed to be completed, if it is in the future. Otherwise `nil`.
    public func dateOnceCompletionIsAllowed(for event: Event, now date: Date = .now) -> Date? {
        let completionDate = switch self {
        case .sameDay:
            Calendar.current.startOfDay(for: event.occurrence.start)
        case .afterStart, .sameDayAfterStart, .duringEvent:
            event.occurrence.start
        }
        // ensure event is in the future, otherwise we are already allowed or we will never be allowed again.
        guard date < completionDate else {
            return nil
        }
        return completionDate
    }
    
    /// Retrieve the date at which the result of `isAllowedToComplete` changes back to disallowed.
    /// - Parameters:
    ///   - event: The event.
    ///   - date: The date that is considered as the `now` date.
    /// - Returns: Returns the date at which the event is no longer allowed to be completed, if it is in the future. Otherwise `nil`.
    public func dateOnceCompletionBecomesDisallowed(for event: Event, now date: Date = .now) -> Date? {
        let endDate: Date? = switch self {
        case .sameDay, .sameDayAfterStart:
            nil
        case .afterStart:
            nil // can be completed forever!
        case .duringEvent:
            event.occurrence.end
        }
        if let endDate {
            guard date < endDate else {
                return nil
            }
        }
        return endDate
    }
}
