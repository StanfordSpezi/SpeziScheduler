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
    public var duration: Duration = .seconds(2)

    private var recurrenceRule: Data?
    // TODO: @Transient private var _recurrence: Calendar.RecurrenceRule?
    // TODO: we can't event store the calendar even though it is not being encoded???
    // TODO: we could do our own wrapper that leaves out the Calendar to store at least most properties!

    /// The recurrence of the schedule.
    public var recurrence: Calendar.RecurrenceRule? {
        get {
            guard let data = recurrenceRule else {
                return nil
            }

            do {
                return try PropertyListDecoder().decode(Calendar.RecurrenceRule.self, from: data)
            } catch {
                print("Failed to decode: \(error)")
                // TODO: logger
            }
            return nil
        }
        set {
            do {
                recurrenceRule = try PropertyListEncoder().encode(newValue)
            } catch {
                print("Failed to encode: \(error)")
                // TODO: logger
            }
        }
    }

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

        // TODO: bring back support for randomly displaced events? random generated seed?
    }


    func dates(for start: Date) -> (start: Date, end: Date) {
        let occurrenceStart: Date
        let occurrenceEnd: Date

        switch duration {
        case .allDay:
            occurrenceStart = Calendar.current.startOfDay(for: start)

            // TODO: shall we just add 24 hours? (we know start is at start of day) and end is exclusive anyways?
            guard let endDate = Calendar.current.date(byAdding: .init(day: 1, second: -1), to: occurrenceStart) else {
                preconditionFailure("Failed to calculate end of date from \(start)")
            }
            occurrenceEnd = endDate
        case let .duration(duration):
            occurrenceStart = start
            occurrenceEnd = occurrenceStart.addingTimeInterval(TimeInterval(duration.components.seconds))
        }

        return (occurrenceStart, occurrenceEnd)
    }
}


extension ILSchedule: Equatable, Sendable {}


extension ILSchedule: Codable {
    private enum CodingKeys: String, CodingKey {
        case _start = "start" // swiftlint:disable:this identifier_name
        case duration
        case recurrenceRule = "recurrence"
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
    ///   - calendar: The calendar
    ///   - interval: The interval in which the daily recurrence repeats (e.g., every `interval`-days).
    ///   - hour: The hour.
    ///   - minute: The minute.
    ///   - second: The second.
    ///   - start: The date at which the schedule starts.
    ///   - end: Optional end date of the schedule. Otherwise, it repeats indefinitely.
    ///   - duration: The duration of a single occurrence. By default one hour.
    /// - Returns: Returns the schedule that repeats daily.
    public static func daily( // swiftlint:disable:this function_default_parameter_at_end
        calendar: Calendar = .current,
        interval: Int = 1,
        hour: Int,
        minute: Int,
        second: Int = 0,
        startingAt start: Date,
        end: Calendar.RecurrenceRule.End = .never,
        duration: Duration = .hours(1)
    ) -> ILSchedule {
        guard let startTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: second, of: start) else {
            preconditionFailure("Failed to set time of start date for daily schedule. Can't set \(hour):\(minute):\(second) for \(start).")
        }
        return ILSchedule(startingAt: startTime, duration: duration, recurrence: .daily(calendar: calendar, interval: interval, end: end))
    }

    /// Create a schedule that repeats weekly.
    ///
    /// - Parameters:
    ///   - calendar: The calendar
    ///   - interval: The interval in which the weekly recurrence repeats (e.g., every `interval`-weeks).
    ///   - weekday: The weekday on which the schedule repeats. If `nil`, it uses the same weekday as the `start` date.
    ///   - hour: The hour.
    ///   - minute: The minute.
    ///   - second: The second.
    ///   - start: The date at which the schedule starts.
    ///   - end: Optional end date of the schedule. Otherwise, it repeats indefinitely.
    ///   - duration: The duration of a single occurrence. By default one hour.
    /// - Returns: Returns the schedule that repeats weekly.
    public static func weekly( // swiftlint:disable:this function_default_parameter_at_end
        calendar: Calendar = .current,
        interval: Int = 1,
        weekday: Locale.Weekday? = nil,
        hour: Int,
        minute: Int,
        second: Int = 0,
        startingAt start: Date,
        end: Calendar.RecurrenceRule.End = .never,
        duration: Duration = .hours(1)
    ) -> ILSchedule {
        guard let startTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: second, of: start) else {
            preconditionFailure("Failed to set time of start time for weekly schedule. Can't set \(hour):\(minute):\(second) for \(start).")
        }
        return ILSchedule(
            startingAt: startTime,
            duration: duration,
            recurrence: .weekly(calendar: calendar, interval: interval, end: end, weekdays: weekday.map { [.every($0)] } ?? [])
        )
    }
}

extension ILSchedule {
    // we are using lazy maps, so these are all single pass operations.

    /// The list of occurrences occurring in a date range.
    ///
    /// - Parameters:
    ///   - start: The start date (inclusive).
    ///   - end: The last date an event might start (exclusive).
    /// - Returns: The list of occurrences. Empty if there are no occurrences in the specified time frame.
    @_disfavoredOverload
    public func occurrences(in range: Range<Date>) -> [Occurrence] {
        Array(occurrences(in: range))
    }


    /// The list of occurrences occurring on a specific day.
    ///
    /// - Parameter date: The day in which the occurrences should occur.
    /// - Returns: The list of occurrences. Empty if there are no occurrences in the specified time frame.
    public func occurrences(inDay date: Date) -> [Occurrence] {
        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else {
            preconditionFailure("Failed to add one day to \(start)")
        }

        return occurrences(in: start..<end)
    }

    /// Retrieve the occurrence for a given occurrence start date in the schedule.
    ///
    /// - Precondition: `index >= 0`
    /// - Parameter date: The start date of the occurrence.
    /// - Returns: Returns the occurrence for the requested index. For example, index `0` returns the first occurrence in the schedule.
    ///     Returns `nil` if the schedule ends before the requested index.
    public func occurrence(forStartDate start: Date) -> Occurrence? {
        guard let nextSecond = Calendar.current.date(byAdding: .second, value: 1, to: start) else {
            preconditionFailure("Failed to add one second to \(start)")
        }

        return occurrences(in: start..<nextSecond).first { occurrence in
            occurrence.start == start
        }
    }

    /// Retrieve all occurrences in the schedule.
    ///
    /// Returns a potential infinite sequence of all occurrences in the schedule.
    ///
    /// - Parameter range: A range that limits the search space. If `nil`, return all occurrences in the schedule.
    /// - Returns: Returns a potentially infinite sequence of ``Occurrence``s.
    public func occurrences(in range: Range<Date>? = nil) -> some Sequence<Occurrence> & Sendable {
        recurrencesSequence(in: range)
            .lazy
            .map { element in
                Occurrence(start: element, schedule: self)
            }
    }

    private func recurrencesSequence(in range: Range<Date>? = nil) -> some Sequence<Date> & Sendable {
        if let recurrence {
            recurrence.recurrences(of: self.start, in: range)
        } else {
            // workaround to make sure we return the same opaque but generic sequence (just equals to `start`)
            Calendar.RecurrenceRule(calendar: .current, frequency: .daily, end: .afterOccurrences(1))
                .recurrences(of: start, in: range)
        }
    }
}
