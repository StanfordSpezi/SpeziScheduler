//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


// TODO: Derrive Occurences/Scheduling!

// TODO: explore Calendar.ReccurenceRule!!

// TODO: can we formulate 5pm every Friday that "adjusts" to the timezone? some might want to have a fixed time?
public struct ScheduleComponent {
    // TODO: allow to specify "text" LocalizedStringResource (e.g., Breakfast, Lunch, etc), otherwise we use the time (and date?)?

    // TODO: Do we need the current calendar?
    /// The start date (inclusive).
    private var _start: Date
    /// The end date (exclusive).
    ///
    /// If `nil`, the schedule repeats indefinitely.
    public var end: Date?
    /// The duration of a single occurrence.
    public var duration: Duration // TODO: Update the all day flag!
    /// The interval between multiple occurrences.
    public var interval: DateComponents

    /// The start date (inclusive).
    public var start: Date {
        get {
            switch duration {
            case .allDay:
                Calendar.current.startOfDay(for: _start)
            default:
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

    /// Indicate if the schedule repeats forever.
    public var repeatsIndefinitely: Bool {
        end == nil
    }

    public init(start: Date, end: Date? = nil, interval: DateComponents, duration: Duration = .hours(1)) {
        // swiftlint:disable:previous function_default_parameter_at_end
        if duration == .allDay {
            self._start = Calendar.current.startOfDay(for: start)
        } else {
            self._start = start
        }
        self.end = end
        self.interval = interval
        self.duration = duration
        // TODO: bring back support for randomly displaced events
        // TODO: bring back support to specify interval by e.g. event count!
    }
}


extension ScheduleComponent: Hashable, Sendable {}


extension ScheduleComponent: Codable {
    private enum CodingKeys: String, CodingKey {
        case _start = "start" // swiftlint:disable:this identifier_name
        case end
        case duration
        case interval
    }
}


extension ScheduleComponent {
    /// Create a schedule for a single occurrence.
    ///
    /// - Parameters:
    ///   - date: The date and time of the occurrence.
    ///   - duration: The duration of the occurrence.
    /// - Returns: Returns the schedule with a single occurrence.
    public static func once(
        at date: Date,
        duration: Duration = .hours(1)
    ) -> ScheduleComponent {
        // setting empty interval
        ScheduleComponent(start: date, interval: DateComponents(), duration: duration)
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
        hour: Int,
        minute: Int,
        second: Int = 0,
        start: Date,
        end: Date? = nil,
        duration: Duration = .hours(1)
    ) -> ScheduleComponent {
        let interval = DateComponents(day: 1)
        guard let startTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: second, of: start) else {
            preconditionFailure("Failed to set time of start date for daily schedule. Can't set \(hour):\(minute):\(second) for \(start).")
        }
        return ScheduleComponent(start: startTime, end: end, interval: interval, duration: duration)
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
        weekday: Locale.Weekday,
        hour: Int,
        minute: Int,
        second: Int = 0,
        start: Date,
        end: Date? = nil,
        duration: Duration = .hours(1)
    ) -> ScheduleComponent {
        let interval = DateComponents(weekOfYear: 1) // TODO: biweekly shorthand?

        guard let weekTime = Calendar.current.date(bySetting: .weekday, value: weekday.calendarWeekday, of: start) else {
            preconditionFailure("Failed to set weekday of start date for weekly schedule. Can't set weekday \(weekday) for \(start).")
        }

        guard let startTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: second, of: weekTime) else {
            preconditionFailure("Failed to set time of week time for weekly schedule. Can't set \(hour):\(minute):\(second) for \(weekTime).")
        }

        return ScheduleComponent(start: startTime, end: end, interval: interval, duration: duration)
    }
}


extension ScheduleComponent { // TODO: make internal?
    // we are using lazy maps, so these are all single pass operations.

    // TODO: precondition docs?
    public func occurrences(from start: Date, to end: Date) -> [Occurrence] {
        precondition(start < end, "Start date must be less than the end date: \(start) < \(end)")

        return occurrences(from: start) // we can't pass the end date to the dates method as we then can't derive the base offset
            .drop { occurrence in
                occurrence.end < start
            }
            .prefix { occurrence in
                occurrence.starts(before: end)
            }
    }

    // TODO: we should support range expressions again
    public func occurrences(betweenIndex startIndex: Int, and stopIndex: Int) -> [Occurrence] {
        // TODO: just an empty list if both indices are the same?
        precondition(startIndex <= stopIndex, "Start index must be less than or equal to the stopIndex: \(startIndex) was bigger than \(stopIndex)")

        return occurrences(from: start)
            .drop { occurrence in
                occurrence.index < startIndex
            }
            .prefix { occurrence in
                occurrence.index < stopIndex
            }
    }

    public func occurrence(forIndex index: Int) -> Occurrence? {
        precondition(index >= 0, "The occurrence index cannot be negative. Received \(index)")
        return occurrences(from: start).first { occurrence in
            occurrence.index == index
        }
    }

    private func occurrences(from date: Date) -> LazyMapSequence<some Sequence<(offset: Int, element: Date)>, Occurrence> {
        occurrenceDates(from: date)
            .enumerated()
            .lazy
            .map { offset, element in
                // TODO: inline this init extension again?
                Occurrence(start: element, schedule: self, index: offset)
                // TODO: indices are intermediate!
            }
    }

    private func occurrenceDates(from date: Date) -> some Sendable & Sequence<Date> {
        if let end {
            Calendar.current.dates(byAdding: interval, startingAt: date, in: start..<end)
        } else {
            // TODO: ensure date is larger than start, otherwise return empty sequence
            // TODO: make sure interval is not empty!
            Calendar.current.dates(byAdding: interval, startingAt: date)
        }
    }
}


extension Occurrence {
    fileprivate init(start: Date, schedule: ScheduleComponent, index: Int) {
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
        default:
            occurrenceStart = start
            occurrenceEnd = occurrenceStart.addingTimeInterval(TimeInterval(schedule.duration.components.seconds))
        }

        // TODO: the index here might be invalid if the Schedule has multiple components!
        self.init(start: occurrenceStart, end: occurrenceEnd, schedule: schedule, index: index)

        if let end = schedule.end {
            precondition(self.starts(before: end), "Created a occurrence that started after the schedule.")
        }
    }
}
