//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


// TODO: can we formulate 5pm every Friday that "adjusts" to the timezone? some might want to have a fixed time?


/// A schedule to describe the occurrences of a task.
///
/// The ``Occurrence``s of a ``ILTask`` are derived from the Schedule.
/// A schedule represents the composition of multiple ``ScheduleComponent``s.
public struct ILSchedule {
    // TODO: allow to specify "text" LocalizedStringResource (e.g., Breakfast, Lunch, etc), otherwise we use the time (and date?)?
    //   => how to store localized values in the database

    /// The start date (inclusive).
    private var _start: Date
    /// The duration of a single occurrence.
    public var duration: Duration
    /// The recurrence of the schedule.
    public var recurrence: Calendar.RecurrenceRule?

    /// The start date (inclusive).
    public var start: Date {
        get {
            switch duration {
            case .allDay:
                Calendar.current.startOfDay(for: _start)
            case .duration:
                _start
            }
        }
        set {
            if duration == .allDay {
                self._start = Calendar.current.startOfDay(for: newValue)
            } else {
                self._start = newValue
            }
        }
    }

    /// Indicate if the schedule repeats indefinitely.
    public var repeatsIndefinitely: Bool {
        if let recurrence {
            recurrence.end == .never
        } else {
            false
        }
    }


    /// Create a new schedule.
    ///
    /// - Parameters:
    ///   - start: The start date of the first event. If a `recurrence` rule is specified, this date is used as a starting point when searching for recurrences.
    ///   - duration: The duration of a single occurrence.
    ///   - recurrence: Optional recurrence rule to specify how often and in which interval the event my reoccur.
    public init(startingAt start: Date, duration: Duration = .hours(1), recurrence: Calendar.RecurrenceRule? = nil) {
        // TODO: code sample in the docs!
        if duration == .allDay {
            self._start = Calendar.current.startOfDay(for: start)
        } else {
            self._start = start
        }
        self.duration = duration
        self.recurrence = recurrence

        // TODO: recurrence.calendar = .autoupdatingCurrent (does that change something?)

        // TODO: bring back support for randomly displaced events
        // TODO: bring back support to specify interval by e.g. event count!
    }
}


extension ILSchedule: Equatable, Sendable {}


extension ILSchedule: Codable {
    private enum CodingKeys: String, CodingKey {
        case _start = "start" // swiftlint:disable:this identifier_name
        case duration
        case recurrence
    }
}


extension ILSchedule {
    /// Create a schedule for a single occurrence.
    ///
    /// - Parameters:
    ///   - date: The date and time of the occurrence.
    ///   - duration: The duration of the occurrence.
    /// - Returns: Returns the schedule with a single occurrence.
    public static func once(
        at date: Date,
        duration: Duration = .hours(1)
    ) -> ILSchedule {
        ILSchedule(startingAt: date, duration: duration)
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
    public static func daily( // swiftlint:disable:this function_default_parameter_at_end
        interval: Int = 1,
        hour: Int, // TODO: still useful?
        minute: Int,
        second: Int = 0,
        start: Date,
        end: Calendar.RecurrenceRule.End = .never,
        duration: Duration = .hours(1)
    ) -> ILSchedule {
        guard let startTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: second, of: start) else {
            preconditionFailure("Failed to set time of start date for daily schedule. Can't set \(hour):\(minute):\(second) for \(start).")
        }
        // TODO: Avoid spelling current calendar all the time?
        return ILSchedule(startingAt: startTime, duration: duration, recurrence: .daily(calendar: .current, interval: interval, end: end))
    }

    /// Create a schedule that repeats weekly.
    ///
    /// - Parameters:
    ///   - weekday: The weekday on which the schedule repeats.
    ///   - hour: The hour.
    ///   - minute: The minute.
    ///   - second: The second.
    ///   - start: The date at which the schedule starts.
    ///   - end: Optional end date of the schedule. Otherwise, it repeats indefinitely.
    ///   - duration: The duration of a single occurrence. By default one hour.
    /// - Returns: Returns the schedule that repeats weekly.
    public static func weekly( // swiftlint:disable:this function_default_parameter_at_end
        interval: Int = 1,
        weekday: Locale.Weekday? = nil,
        hour: Int,
        minute: Int,
        second: Int = 0,
        start: Date,
        end: Calendar.RecurrenceRule.End = .never,
        duration: Duration = .hours(1)
    ) -> ILSchedule {
        guard let startTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: second, of: start) else {
            preconditionFailure("Failed to set time of start time for weekly schedule. Can't set \(hour):\(minute):\(second) for \(start).")
        }
        return ILSchedule(
            startingAt: startTime,
            duration: duration,
            recurrence: .weekly(calendar: .current, interval: interval, end: end, weekdays: weekday.map { [.every($0)] } ?? [])
        )
    }
}

extension ILSchedule {
    // we are using lazy maps, so these are all single pass operations.

    /// The list of occurrences occurring between two dates.
    ///
    /// - Precondition: `start < end`
    /// - Parameters:
    ///   - start: The start date (inclusive).
    ///   - end: The last date an event might start (exclusive).
    /// - Returns: The list of occurrences. Empty if there are no occurrences in the specified time frame.
    public func occurrences(from start: Date, to end: Date) -> [Occurrence] {
        precondition(start < end, "Start date must be less than the end date: \(start) < \(end)")

        return occurrences() // we can't pass the end date to the dates method as we then can't derive the base offset
            .drop { occurrence in
                occurrence.end < start
            }
            .prefix { occurrence in
                occurrence.starts(before: end)
            }
    }

    /// Retrieve the list of occurrences between two occurrence indices.
    ///
    /// - Precondition: `startIndex <= stopIndex`
    /// - Parameters:
    ///   - startIndex: The occurrence of the first occurrence of return (inclusive).
    ///   - stopIndex: The index of the last occurrence (exclusive).
    /// - Returns: The list of occurrences in the range specified for the supplied indices
    public func occurrences(betweenIndex startIndex: Int, and stopIndex: Int) -> [Occurrence] {
        // TODO: support range expressions?
        precondition(startIndex <= stopIndex, "Start index must be less than or equal to the stopIndex: \(startIndex) was bigger than \(stopIndex)")

        return occurrences()
            .drop { occurrence in
                occurrence.index < startIndex
            }
            .prefix { occurrence in
                occurrence.index < stopIndex
            }
    }

    /// Retrieve the occurrence for a given occurrence index in the schedule.
    ///
    /// - Precondition: `index >= 0`
    /// - Parameter index: The index of the occurrence.
    /// - Returns: Returns the occurrence for the requested index. For example, index `0` returns the first occurrence in the schedule.
    ///     Returns `nil` if the schedule ends before the requested index.
    public func occurrence(forIndex index: Int) -> Occurrence? {
        precondition(index >= 0, "The occurrence index cannot be negative. Received \(index)")
        return occurrences().first { occurrence in
            occurrence.index == index
        }
    }

    public func occurrences() -> LazyMapSequence<some Sequence<(offset: Int, element: Date)>, Occurrence> {
        // TODO: if we do not need the index, we could limit the date range and make things more efficient!
        recurrencesSequence()
            .enumerated()
            .lazy
            .map { offset, element in
                // TODO: inline this init extension again?
                Occurrence(start: element, schedule: self, index: offset)
            }
    }

    private func recurrencesSequence() -> some Sequence<Date> & Sendable {
        if let recurrence {
            recurrence.recurrences(of: self.start)
        } else {
            // workaround to make sure we return the same opaque but generic sequence (just equals to `start`)
            Calendar.RecurrenceRule(calendar: .current, frequency: .daily, end: .afterOccurrences(1))
                .recurrences(of: start)
        }
    }
}


extension Occurrence {
    fileprivate init(start: Date, schedule: ILSchedule, index: Int) {
        let occurrenceStart: Date
        let occurrenceEnd: Date

        switch schedule.duration {
        case .allDay: // TODO: there is a difference between allDay and 24 hour duration?
            occurrenceStart = Calendar.current.startOfDay(for: start)

            // TODO: why not just add 24 hours?
            guard let endDate = Calendar.current.date(byAdding: .init(day: 1, second: -1), to: occurrenceStart) else {
                preconditionFailure("Failed to calculate end of date from \(start)")
            }
            occurrenceEnd = endDate
        case let .duration(duration):
            occurrenceStart = start
            occurrenceEnd = occurrenceStart.addingTimeInterval(TimeInterval(duration.components.seconds))
        }

        // TODO: the index here might be invalid if the Schedule has multiple components!
        self.init(start: occurrenceStart, end: occurrenceEnd, schedule: schedule, index: index)
    }
}
