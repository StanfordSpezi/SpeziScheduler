//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension ILSchedule {
    /// A wrapper around `Calendar.RecurrenceRule` to make SwiftData happy.
    ///
    /// SwiftData crashes when encountering a protocol type (specifically a AnyObject protocol type) when parsing models (independently how deeply nested they are).
    /// This is a problem with `Calendar.RecurrenceRule` as it stores an instance of `Calendar` which again stores its concrete implementation using a reference type
    /// using a protocol type, see https://github.com/apple/swift-foundation/blob/ef8c1d539cd8df3da5151befd95afee5fa64890e/Sources/FoundationEssentials/Calendar/Calendar.swift#L37.
    /// Therefore, we create our own RecurrenceRule type that copies everything SwiftData can handle and stores the calendar by encoding it
    struct RecurrenceRule {
        var calendar: Data

        let matchingPolicy: Calendar.MatchingPolicy
        let repeatedTimePolicy: Calendar.RepeatedTimePolicy
        let frequency: Calendar.RecurrenceRule.Frequency
        let interval: Int
        let end: Calendar.RecurrenceRule.End

        let seconds: [Int]
        let minutes: [Int]
        let hours: [Int]
        let weekdays: [Calendar.RecurrenceRule.Weekday]
        let daysOfTheMonth: [Int]
        let daysOfTheYear: [Int]
        let months: [Calendar.RecurrenceRule.Month]
        let weeks: [Int]
        let setPositions: [Int]

        var theCalendar: Calendar {
            @storageRestrictions(initializes: calendar)
            init(initialValue) {
                do {
                    calendar = try PropertyListEncoder().encode(initialValue)
                } catch {
                    preconditionFailure("Failed to encode calendar for value \(initialValue): \(error)")
                }
            }
            get {
                do {
                    return try PropertyListDecoder().decode(Calendar.self, from: calendar)
                } catch {
                    preconditionFailure("Failed to decode calendar from \(calendar): \(error)")
                }
            }
        }
    }
}


extension ILSchedule.RecurrenceRule: Equatable, Sendable {}

extension ILSchedule.RecurrenceRule: Codable {
    private enum CodingKeys: String, CodingKey {
        case calendar
        case matchingPolicy
        case repeatedTimePolicy
        case frequency
        case interval
        case end
        case seconds
        case minutes
        case hours
        case weekdays
        case daysOfTheMonth
        case daysOfTheYear
        case months
        case weeks
        case setPositions
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        calendar = try container.decode(Data.self, forKey: .calendar)
        matchingPolicy = try container.decode(Calendar.MatchingPolicy.self, forKey: .matchingPolicy)
        repeatedTimePolicy = try container.decode(Calendar.RepeatedTimePolicy.self, forKey: .repeatedTimePolicy)
        frequency = try container.decode(Calendar.RecurrenceRule.Frequency.self, forKey: .frequency)
        interval = try container.decode(Int.self, forKey: .interval)
        end = try container.decode(Calendar.RecurrenceRule.End.self, forKey: .end)
        seconds = try container.decode([Int].self, forKey: .seconds)
        minutes = try container.decode([Int].self, forKey: .minutes)
        hours = try container.decode([Int].self, forKey: .hours)
        weekdays = try container.decode([Calendar.RecurrenceRule.Weekday].self, forKey: .weekdays)
        daysOfTheMonth = try container.decode([Int].self, forKey: .daysOfTheMonth)
        daysOfTheYear = try container.decode([Int].self, forKey: .daysOfTheYear)
        months = try container.decode([Calendar.RecurrenceRule.Month].self, forKey: .months)
        weeks = try container.decode([Int].self, forKey: .weeks)
        setPositions = try container.decode([Int].self, forKey: .setPositions)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(calendar, forKey: .calendar)
        try container.encode(matchingPolicy, forKey: .matchingPolicy)
        try container.encode(repeatedTimePolicy, forKey: .repeatedTimePolicy)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(interval, forKey: .interval)
        try container.encode(end, forKey: .end)
        try container.encode(seconds, forKey: .seconds)
        try container.encode(minutes, forKey: .minutes)
        try container.encode(hours, forKey: .hours)
        try container.encode(weekdays, forKey: .weekdays)
        try container.encode(daysOfTheMonth, forKey: .daysOfTheMonth)
        try container.encode(daysOfTheYear, forKey: .daysOfTheYear)
        try container.encode(months, forKey: .months)
        try container.encode(weeks, forKey: .weeks)
        try container.encode(setPositions, forKey: .setPositions)
    }
}


extension ILSchedule.RecurrenceRule {
    init(from recurrenceRule: Calendar.RecurrenceRule) {
        self.theCalendar = recurrenceRule.calendar

        self.matchingPolicy = recurrenceRule.matchingPolicy
        self.repeatedTimePolicy = recurrenceRule.repeatedTimePolicy
        self.frequency = recurrenceRule.frequency
        self.interval = recurrenceRule.interval
        self.end = recurrenceRule.end

        self.seconds = recurrenceRule.seconds
        self.minutes = recurrenceRule.minutes
        self.hours = recurrenceRule.hours
        self.weekdays = recurrenceRule.weekdays
        self.daysOfTheMonth = recurrenceRule.daysOfTheMonth
        self.daysOfTheYear = recurrenceRule.daysOfTheYear
        self.months = recurrenceRule.months
        self.weeks = recurrenceRule.weeks
        self.setPositions = recurrenceRule.setPositions
    }
}


extension Calendar.RecurrenceRule {
    init(from recurrenceRule: ILSchedule.RecurrenceRule) {
        self.init(
            calendar: recurrenceRule.theCalendar,
            frequency: recurrenceRule.frequency,
            interval: recurrenceRule.interval,
            end: recurrenceRule.end,
            matchingPolicy: recurrenceRule.matchingPolicy,
            repeatedTimePolicy: recurrenceRule.repeatedTimePolicy,
            months: recurrenceRule.months,
            daysOfTheYear: recurrenceRule.daysOfTheYear,
            daysOfTheMonth: recurrenceRule.daysOfTheMonth,
            weeks: recurrenceRule.weeks,
            weekdays: recurrenceRule.weekdays,
            hours: recurrenceRule.hours,
            minutes: recurrenceRule.minutes,
            seconds: recurrenceRule.seconds,
            setPositions: recurrenceRule.setPositions
        )
    }
}
