//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// A schedule to describe the occurrences of a task.
///
/// The ``Occurrence``s of a ``ILTask`` are derived from the Schedule.
/// A schedule represents the composition of multiple ``ScheduleComponent``s.
public struct ILSchedule {
    // TODO: flatten Codable representation?

    /// The components of the schedule.
    ///
    /// Each component can describe one or multiple (repeating) occurrences.
    public private(set) var components: [ScheduleComponent] // TODO: Make it let? 

    /// The first start date of the schedule.
    public var start: Date {
        guard let component = components.min(by: { $0.start < $1.start }) else {
            preconditionFailure("State inconsistency. Encountered empty schedule!")
        }
        return component.start
    }

    /// The end date of the schedule if it doesn't repeat indefinitely.
    public var end: Date? {
        let endDates = components.compactMap { component in
            component.end
        }

        if endDates.count < components.count {
            return nil // there exists a component without a end date. the whole schedule is infinite
        }
        return endDates.max()
    }

    /// Determine if the schedule repeats indefinitely.
    public var repeatsIndefinitely: Bool {
        components.contains { component in
            component.repeatsIndefinitely
        }
    }

    /// Create a new schedule through composition of individual components.
    /// - Parameter components: The array of schedule components.
    /// - Precondition: `!components.isEmpty`
    public init(composing components: [ScheduleComponent]) {
        assert(!components.isEmpty, "You cannot create a schedule with zero components!")
        self.components = components.sorted { lhs, rhs in
            lhs.start < rhs.start
        }
    }

    /// Create a new schedule through composition of schedules.
    /// - Parameter schedules: The array of schedules.
    @_disfavoredOverload
    public init(composing schedules: [ILSchedule]) {
        self.init(composing: schedules.flatMap { schedule in
            schedule.components
        })
    }

    /// Create a new schedule through composition of individual components.
    /// - Parameter components: The array of schedule components.
    /// - Precondition: `!components.isEmpty`
    public init(composing components: ScheduleComponent...) {
        self.init(composing: components)
    }

    /// Create a new schedule through composition of schedules.
    /// - Parameter schedules: The array of schedules.
    @_disfavoredOverload
    public init(composing schedules: ILSchedule...) {
        self.init(composing: schedules)
    }
}


extension ILSchedule: Codable {}


extension ILSchedule {
    public static func once(
        at date: Date,
        duration: Duration = .hours(1)
    ) -> ILSchedule {
        ILSchedule(composing: .once(at: date, duration: duration))
    }

    /// Create a schedule that repeats daily.
    ///
    /// - Parameters:
    ///   - hour: The hour.
    ///   - minute: The minute.
    ///   - second: The second.
    ///   - start: The date at which the schedule starts.
    ///   - end: Optional end date of the schedule. Otherwise, it repeats indefinitely.
    ///   - duration: The duration of a single occurrence. By default one hour.
    /// - Returns: Returns the schedule that repeats daily.
    public static func daily(hour: Int, minute: Int, second: Int = 0, start: Date, end: Date? = nil, duration: Duration = .hours(1)) -> ILSchedule {
        // swiftlint:disable:previous function_default_parameter_at_end
        // TODO: some events might not have the semantic of a duration?
        ILSchedule(composing: .daily(hour: hour, minute: minute, second: second, start: start, end: end, duration: duration))
    }

    /// Create a schedule that repeats weekly.
    ///
    /// - Parameters:
    ///   - weekday: The weekday on which the schedule repeats
    ///   - hour: The hour.
    ///   - minute: The minute.
    ///   - second: The second.
    ///   - start: The date at which the schedule starts.
    ///   - end: Optional end date of the schedule. Otherwise, it repeats indefinitely.
    ///   - duration: The duration of a single occurrence. By default one hour.
    /// - Returns: Returns the schedule that repeats weekly.
    public static func weekly( // swiftlint:disable:this function_default_parameter_at_end
        weekday: Int,
        hour: Int,
        minute: Int,
        second: Int = 0,
        start: Date,
        end: Date? = nil,
        duration: Duration = .hours(1)
    ) -> ILSchedule {
        ILSchedule(composing: .weekly(weekday: weekday, hour: hour, minute: minute, second: second, start: start, end: end, duration: duration))
    }
}


extension ILSchedule {
    /// The list of occurrences occurring between two dates.
    ///
    /// - Precondition: `start < end`
    /// - Parameters:
    ///   - start: The start date (inclusive).
    ///   - end: The last date an event might start (exclusive).
    /// - Returns: The list of occurrences. Empty if there are no occurrences in the specified time frame.
    public func occurrences(from start: Date, to end: Date) -> [Occurrence] {
        precondition(start < end, "Start date must be less than the end date: \(start) < \(end)")

        let occurrences = components
            .filter { $0.start < end }
            .flatMap { $0.occurrences(from: $0.start, to: end) }

        let filtered = occurrences.filter { $0.end >= start }

        let firstOccurrence = filtered.count - occurrences.count

        return filtered.mergeOccurrences(startingOccurrence: firstOccurrence)
    }

    /// Retrieve the occurrence for a given occurrence index in the schedule.
    ///
    /// - Precondition: `index >= 0`
    /// - Parameter index: The index of the occurrence.
    /// - Returns: Returns the occurrence for the requested index. For example, index `0` returns the first occurrence in the schedule.
    ///     Returns `nil` if the schedule ends before the requested index.
    public func occurrences(forIndex index: Int) -> Occurrence? {
        precondition(index >= 0, "The occurrence index cannot be negative")

        // TODO: we could optimize this my having a lazy collection approach! that sorts itself!
        let occurrences = components
            .flatMap { component in
                component.occurrences(betweenIndex: 0, and: index + 1)
            }
            .mergeOccurrences()

        guard occurrences.count >= index else {
            return nil // the whole schedule might end before the index
        }

        return occurrences[index]
    }

    // TODO: func exists(onDay date: Date) -> Bool {
    /*

    func exists(onDay date: Date) -> Bool {
        let firstMomentOfTheDay = Calendar.current.startOfDay(for: date)
        let lastMomentOfTheDay = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: firstMomentOfTheDay)!

        // If there is no end date, we just have to check that it starts before the end of the given day.
        guard let end = endDate() else {
            return startDate() <= lastMomentOfTheDay
        }

        // If there is an end date, the we need to ensure that it has already started, and hasn't ended yet.
        let startedOnTime = startDate() < lastMomentOfTheDay
        let didntEndTooEarly = end > firstMomentOfTheDay

        return startedOnTime && didntEndTooEarly
    }
    */
}


extension Array where Element == Occurrence {
    // TODO: rename argument!
    fileprivate func mergeOccurrences(startingOccurrence: Int = 0) -> Self {
        self
            .sorted { $0.start < $1.start }
            .enumerated()
            .map { offset, occurrence in
                // TODO: just have a mutable property?
                Occurrence(start: occurrence.start, end: occurrence.end, schedule: occurrence.schedule, index: startingOccurrence + offset)
            }
    }
}
