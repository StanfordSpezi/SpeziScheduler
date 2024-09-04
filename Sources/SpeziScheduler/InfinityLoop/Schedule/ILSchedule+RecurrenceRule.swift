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


extension ILSchedule.RecurrenceRule: Equatable, Sendable, Codable {}


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
