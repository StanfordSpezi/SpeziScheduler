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
    /// The event is only allowed to be completed while it is occurring.
    case duringEvent
    /// The event is allowed to be completed at any time before, during, or after its occurrence
    case anytime
}


extension AllowedCompletionPolicy {
    /// Determine if an event is currently allowed to be completed.
    /// - Parameters:
    ///   - event: The event.
    ///   - now: The date that is considered as the `now` date.
    /// - Returns: `true` if the event is currently allowed to be completed. `false` otherwise. If the date at which the event is allowed to be completed is still in the future,
    ///     you can use the ``dateOnceCompletionIsAllowed(for:now:)`` and ``dateOnceCompletionBecomesDisallowed(for:now:)`` methods to retrieve the time
    ///     when you need to update your UI.
    public func isAllowedToComplete(event: Event, now: Date = .now) -> Bool {
        switch self {
        case .sameDay:
            Calendar.current.isDateInToday(now)
        case .afterStart:
            now >= event.occurrence.start
        case .sameDayAfterStart:
            Calendar.current.isDateInToday(now) && now >= event.occurrence.start
        case .duringEvent:
            (event.occurrence.start..<event.occurrence.end).contains(now)
        case .anytime:
            true
        }
    }
    
    /// Retrieve the date at which the result of `isAllowedToComplete` changes to allowed.
    /// - Parameters:
    ///   - event: The event.
    ///   - now: The date that is considered as the `now` date.
    /// - Returns: Returns the date at which the event is allowed to be completed, if it is in the future, otherwise `nil`.
    ///     ``AllowedCompletionPolicy/anytime`` is an exception, and the function will return `Date.distantPast` in this case, since such events are always allowed to be completed.
    public func dateOnceCompletionIsAllowed(for event: Event, now: Date = .now) -> Date? {
        let completionDate: Date
        switch self {
        case .sameDay:
            completionDate = Calendar.current.startOfDay(for: event.occurrence.start)
        case .afterStart, .sameDayAfterStart, .duringEvent:
            completionDate = event.occurrence.start
        case .anytime:
            return .distantPast
        }
        // ensure event is in the future, otherwise we are already allowed or we will never be allowed again.
        guard now < completionDate else {
            return nil
        }
        return completionDate
    }
    
    /// Retrieve the date at which the result of `isAllowedToComplete` changes back to disallowed.
    /// - Parameters:
    ///   - event: The event.
    ///   - date: The date that is considered as the `now` date.
    /// - Returns: Returns the date at which the event is no longer allowed to be completed, if it is in the future, otherwise `nil`.
    ///     For ``AllowedCompletionPolicy/anytime``, this function returns `Date.distantFuture`.
    public func dateOnceCompletionBecomesDisallowed(for event: Event, now: Date = .now) -> Date? {
        let endDate: Date?
        switch self {
        case .sameDay, .sameDayAfterStart:
            endDate = nil
        case .afterStart:
            endDate = nil // can be completed forever!
        case .duringEvent:
            endDate = event.occurrence.end
        case .anytime:
            return .distantFuture
        }
        if let endDate {
            guard now < endDate else {
                return nil
            }
        }
        return endDate
    }
}
