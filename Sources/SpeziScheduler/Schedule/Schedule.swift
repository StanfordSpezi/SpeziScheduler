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
/// The ``Occurrence``s of a ``Task`` are derived from the Schedule.
///
/// The Schedule uses Swift's [`RecurrenceRule`](https://developer.apple.com/documentation/foundation/calendar/recurrencerule) under to hood to express flexible
/// recurrence schedules. You can configure a schedule using any recurrence rule you want.
///
/// Schedule also provides some convenience initializers like ``once(at:duration:)``, ``daily(calendar:interval:hour:minute:second:startingAt:end:duration:)``
/// or ``weekly(calendar:interval:weekday:hour:minute:second:startingAt:end:duration:)``.
///
/// ```swift
/// // create a schedule at 8am daily, starting from today, reoccur indefinitely
/// let schedule: Schedule = .daily(hour: 8, minute: 0, startingAt: .today)
/// ```
///
/// ## Topics
///
/// ### Properties
/// - ``start``
/// - ``duration-swift.property``
/// - ``recurrence``
/// - ``repeatsIndefinitely``
///
/// ### Creating Schedules
/// - ``init(startingAt:duration:recurrence:)``
/// - ``daily(calendar:interval:hour:minute:second:startingAt:end:duration:)``
/// - ``weekly(calendar:interval:weekday:hour:minute:second:startingAt:end:duration:)``
/// - ``once(at:duration:)``
///
/// ### Retrieving Occurrences
/// - ``occurrences(in:)-1r4pv``
/// - ``occurrences(inDay:)``
/// - ``occurrences(in:)-3a9p3``
/// - ``occurrence(forStartDate:)``
public struct Schedule {
    /// The start date (inclusive).
    private var startDate: Date
    /// The duration of a single occurrence.
    ///
    /// We need a separate storage container as SwiftData cannot store values of type `Swift.Duration`.
    private var scheduleDuration: Duration.SwiftDataDuration


    private var recurrenceRule: Data?

    /// A simpler representation of the recurrence rule used for notification scheduling.
    ///
    /// Some simple recurrences can be expressed as an interval using `DateComponents`. In these cases, we are able to more efficiently
    /// schedule notifications. Therefore, if possible we augment the interval hint for recurrence rules we know are simple enough.
    ///
    /// This is only possible if `DateComponents` doesn't describe another occurrence between `now` and `startDate`. Therefore, we might need to schedule
    /// these occurrences manually, till we reach a date where `now` is near enough at the `startDate`.
    private(set) var notificationMatchingHint: DateComponents?
    // TODO: when does this end???
    // TODO: we can only do that if we are post the startDate (e.g., daily but only starting next week) =>

    /// The duration of a single occurrence.
    ///
    /// If the duration is `nil`, the schedule provides a start date only. The end date will be automatically chosen to be end of day.
    public var duration: Duration {
        @storageRestrictions(initializes: scheduleDuration)
        init(initialValue) {
            scheduleDuration = Duration.SwiftDataDuration(from: initialValue)
        }
        get {
            Duration(from: scheduleDuration)
        }
        set {
            scheduleDuration = Duration.SwiftDataDuration(from: newValue)
        }
    }

    /// The recurrence of the schedule.
    public var recurrence: Calendar.RecurrenceRule? {
        @storageRestrictions(initializes: recurrenceRule)
        init(initialValue) {
            recurrenceRule = initialValue.map { Data(encoding: $0) }
        }
        get {
            recurrenceRule.map { Calendar.RecurrenceRule(fromEncoded: $0) }
        }
        set {
            recurrenceRule = newValue.map { Data(encoding: $0) }

            // if someone updates the recurrence rule, our notificationMatchingHint is not valid anymore
            // TODO: there are properties that can be safely changed!
            notificationMatchingHint = nil
        }
    }

    /// The start date (inclusive).
    public var start: Date {
        @storageRestrictions(initializes: startDate, accesses: scheduleDuration)
        init(initialValue) {
            if scheduleDuration == .allDay {
                startDate = Calendar.current.startOfDay(for: initialValue)
            } else {
                startDate = initialValue
            }
        }
        get {
            switch duration {
            case .allDay:
                Calendar.current.startOfDay(for: startDate)
            case .duration, .tillEndOfDay:
                startDate
            }
        }
        set {
            if duration == .allDay {
                self.startDate = Calendar.current.startOfDay(for: newValue)
            } else {
                self.startDate = newValue
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


    init(
        startingAt start: Date,
        duration: Duration = .tillEndOfDay,
        recurrence: Calendar.RecurrenceRule?,
        notificationIntervalHint: DateComponents?
    ) {
        self.duration = duration
        self.start = start
        self.recurrence = recurrence
        self.notificationMatchingHint = notificationIntervalHint
    }


    /// Create a new schedule.
    ///
    /// ```swift
    /// // the first weekend day of each month (either saturday or sunday, whichever comes first)
    /// var recurrence: Calendar.RecurrenceRule = .monthly(calendar: .current, end: .afterOccurrences(5))
    /// recurrence.weekdays = [.nth(1, .saturday), .nth(1, .sunday)]
    /// recurrence.setPositions = [1]
    ///
    /// let schedule = Schedule(startingAt: .today, recurrence: recurrence)
    /// ```
    ///
    /// - Parameters:
    ///   - start: The start date of the first event. If a `recurrence` rule is specified, this date is used as a starting point when searching for recurrences.
    ///   - duration: The duration of a single occurrence.
    ///   - recurrence: Optional recurrence rule to specify how often and in which interval the event my reoccur.
    public init(startingAt start: Date, duration: Duration = .tillEndOfDay, recurrence: Calendar.RecurrenceRule? = nil) {
        self.init(startingAt: start, duration: duration, recurrence: recurrence, notificationIntervalHint: nil)
    }


    func dates(for start: Date) -> (start: Date, end: Date) {
        let occurrenceStart: Date
        let occurrenceEnd: Date

        switch duration {
        case .allDay:
            occurrenceStart = Calendar.current.startOfDay(for: start)

            guard let endDate = Calendar.current.date(byAdding: .init(day: 1, second: -1), to: occurrenceStart) else {
                preconditionFailure("Failed to calculate end of date from \(start)")
            }
            occurrenceEnd = endDate
        case let .duration(duration):
            occurrenceStart = start
            occurrenceEnd = occurrenceStart.addingTimeInterval(TimeInterval(duration.components.seconds))
        case .tillEndOfDay:
            occurrenceStart = start

            let startOfDay = Calendar.current.startOfDay(for: start)
            guard let endOfDay = Calendar.current.date(byAdding: .init(day: 1, second: -1), to: startOfDay) else {
                preconditionFailure("Failed to calculate end of day from \(startOfDay)")
            }
            occurrenceEnd = endOfDay
        }

        return (occurrenceStart, occurrenceEnd)
    }
}


extension Schedule: Equatable, Sendable, Codable {
    private enum CodingKeys: String, CodingKey {
        case startDate
        case scheduleDuration
        case recurrenceRule
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.scheduleDuration = try container.decode(Schedule.Duration.SwiftDataDuration.self, forKey: .scheduleDuration)
        self.recurrenceRule = try container.decodeIfPresent(Data.self, forKey: .recurrenceRule)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(scheduleDuration, forKey: .scheduleDuration)
        try container.encode(recurrenceRule, forKey: .recurrenceRule)
    }
}


extension Schedule {
    /// Create a schedule for a single occurrence.
    ///
    /// ```swift
    /// // create a schedule that occurs exactly once, tomorrow at the same time as now
    /// let date = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
    /// let schedule: Schedule = .once(at: date)
    /// ```
    ///
    /// - Parameters:
    ///   - date: The date and time of the occurrence.
    ///   - duration: The duration of the occurrence.
    /// - Returns: Returns the schedule with a single occurrence.
    public static func once(
        at date: Date,
        duration: Duration = .tillEndOfDay
    ) -> Schedule {
        Schedule(startingAt: date, duration: duration)
    }

    /// Create a schedule that repeats daily.
    ///
    /// ```swift
    /// // create a schedule at 8 am daily, starting from today, reoccur indefinitely
    /// let schedule: Schedule = .daily(hour: 8, minute: 0, startingAt: .today)
    /// ```
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
        duration: Duration = .tillEndOfDay
    ) -> Schedule {
        guard let startTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: second, of: start) else {
            preconditionFailure("Failed to set time of start date for daily schedule. Can't set \(hour):\(minute):\(second) for \(start).")
        }

        let notificationIntervalHint = Self.notificationIntervalHint(
            forMatchingInterval: interval,
            calendar: calendar,
            hour: hour,
            minute: minute,
            second: second,
            consider: duration
        )

        return Schedule(
            startingAt: startTime,
            duration: duration,
            recurrence: .daily(calendar: calendar, interval: interval, end: end),
            notificationIntervalHint: notificationIntervalHint
        )
    }

    /// Create a schedule that repeats weekly.
    ///
    /// ```swift
    /// // create a schedule at 8 am bi-weekly, starting from the next wednesday from today, reoccur indefinitely
    /// let schedule: Schedule = .weekly(interval: 2, weekday: .wednesday, hour: 8, minute: 0, startingAt: .today)
    /// ```
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
        duration: Duration = .tillEndOfDay
    ) -> Schedule {
        guard let startTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: second, of: start) else {
            preconditionFailure("Failed to set time of start time for weekly schedule. Can't set \(hour):\(minute):\(second) for \(start).")
        }

        let weekdayNum = weekday.map { $0.ordinal } ?? Calendar.current.component(.weekday, from: startTime)
        let notificationIntervalHint = Self.notificationIntervalHint(
            forMatchingInterval: interval,
            calendar: calendar,
            hour: hour,
            minute: minute,
            second: second,
            weekday: weekdayNum,
            consider: duration
        )

        return Schedule(
            startingAt: startTime,
            duration: duration,
            recurrence: .weekly(calendar: calendar, interval: interval, end: end, weekdays: weekday.map { [.every($0)] } ?? []),
            notificationIntervalHint: notificationIntervalHint
        )
    }
}

extension Schedule {
    // we are using lazy maps, so these are all single pass operations.

    /// The list of occurrences occurring in a date range.
    ///
    /// - Parameter range: The date range to retrieve all occurrences for.
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
    /// - Parameter start: The start date of the occurrence.
    /// - Returns: Returns the Occurrence if there is an occurrence for this schedule at exactly the passed `start` date. Otherwise, `nil`.
    public func occurrence(forStartDate start: Date) -> Occurrence? {
        guard let nextSecond = Calendar.current.date(byAdding: .second, value: 1, to: start) else {
            preconditionFailure("Failed to add one second to \(start)")
        }

        return occurrences(in: start..<nextSecond).first { occurrence in
            occurrence.start == start
        }
    }

    /// Retrieve the sequence of all occurrences in the schedule.
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

    func nextOccurrence(from date: Date) -> Occurrence? {
        occurrences(in: date..<Date.distantFuture)
            .first { _ in
                true
            }
    }

    private func recurrencesSequence(in range: Range<Date>? = nil) -> some Sequence<Date> {
        let start = start
        let rangeUsedWithRule: Range<Date>?

        // When using `afterOccurrences(_:)` as an `end` condition, recurrence rule counts occurrences only base do on the specified range not
        // based on the start date. Therefore, we must make sure that the lower-bound of the range is always set to the start date.
        // Once SF-0010 is available, we could access if `end.occurrences` is not `nil` and only apply the custom range in this case.
        // See https://github.com/apple/swift-foundation/blob/main/Proposals/0010-calendar-recurrence-rule-end-count-and-date.md.
        rangeUsedWithRule = range.map { range in
            start..<range.upperBound
        }

        return if let recurrence {
            recurrence.recurrences(of: start, in: rangeUsedWithRule)
                .lazy
                .filter { date in
                    if let range {
                        date >= range.lowerBound
                    } else {
                        true
                    }
                }
        } else {
            // workaround to make sure we return the same opaque but generic sequence (just equals to `start`)
            Calendar.RecurrenceRule(calendar: .current, frequency: .daily, end: .afterOccurrences(1))
                .recurrences(of: start, in: rangeUsedWithRule)
                .lazy
                .filter { date in
                    if let range {
                        date >= range.lowerBound
                    } else {
                        true
                    }
                }
        }
    }
}


extension Schedule: CustomStringConvertible {
    public var description: String {
        """
        Schedule(\
        start: \(start),
        duration: \(scheduleDuration),
        recurrence: \(recurrence.map { "\($0)" } ?? "nil")
        )
        """
    }
}


extension Calendar.RecurrenceRule {
    fileprivate init(fromEncoded data: Data) {
        do {
            self = try PropertyListDecoder().decode(Calendar.RecurrenceRule.self, from: data)
        } catch {
            preconditionFailure("Failed to decode calendar from \(data): \(error)")
        }
    }
}


extension Data {
    fileprivate init(encoding recurrenceRule: Calendar.RecurrenceRule) {
        do {
            self = try PropertyListEncoder().encode(recurrenceRule)
        } catch {
            preconditionFailure("Failed to encode recurrence rule \(recurrenceRule): \(error)")
        }
    }
}
