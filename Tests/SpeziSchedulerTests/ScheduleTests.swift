//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@testable import SpeziScheduler
import Testing


@Suite
struct ScheduleTests {
    @Test
    func onceSchedule() throws {
        let startDate: Date = try .withTestDate(hour: 9, minute: 23, second: 25)
        let schedule: Schedule = .once(at: startDate, duration: .hours(2))

        let occurrences = schedule.occurrences()
        var iterator = occurrences.makeIterator()

        let occurrence1 = try #require(iterator.next())
        #expect(try occurrence1.start == .withTestDate(hour: 9, minute: 23, second: 25))
        #expect(try occurrence1.end == .withTestDate(hour: 11, minute: 23, second: 25))

        #expect(iterator.next() == nil)
    }

    @Test
    func nextOccurrenceOnceSchedule() throws {
        let startDate: Date = try .withTestDate(hour: 9, minute: 23, second: 25)
        let schedule: Schedule = .once(at: startDate, duration: .hours(2))

        let occurrence = try #require(schedule.nextOccurrence(in: try .withTestDate(hour: 9, minute: 3)...))
        #expect(try schedule.nextOccurrence(in: .withTestDate(hour: 9, minute: 25)...) == nil)

        #expect(try occurrence.start == .withTestDate(hour: 9, minute: 23, second: 25))
        #expect(try occurrence.end == .withTestDate(hour: 11, minute: 23, second: 25))

        let occurrences = try schedule.nextOccurrences(in: .withTestDate(hour: 9, minute: 3)..., count: 2)
        try #require(occurrences.count == 1)
        #expect(occurrences[0] == occurrence)
    }

    @Test
    func nextOccurrence() throws {
        let startDate: Date = try .withTestDate(hour: 9, minute: 23, second: 25)
        let schedule: Schedule = .daily(hour: 12, minute: 35, startingAt: startDate, end: .afterOccurrences(3))

        let occurrence = try #require(schedule.nextOccurrence(in: try .withTestDate(hour: 9, minute: 3)...))
        #expect(try schedule.nextOccurrence(in: .withTestDate(day: 26, hour: 14, minute: 0)...) == nil)

        #expect(try occurrence.start == .withTestDate(hour: 12, minute: 35))

        let occurrences = try schedule.nextOccurrences(in: .withTestDate(hour: 9, minute: 3)..., count: 2)
        try #require(occurrences.count == 2)
        #expect(occurrences[0] == occurrence)

        let occurrence1 = occurrences[1]
        #expect(try occurrence1.start == .withTestDate(day: 25, hour: 12, minute: 35, second: 0))
    }

    @Test
    func nextOccurrenceInfinite() throws {
        let clock = ContinuousClock()

        let startDate: Date = try .withTestDate(hour: 9, minute: 23, second: 25)
        let schedule: Schedule = .daily(hour: 12, minute: 35, startingAt: startDate)

        var rawOccurrence: Occurrence?
        let duration = try clock.measure {
            rawOccurrence = schedule.nextOccurrence(in: try .withTestDate(hour: 9, minute: 3)...)
        }
        let occurrence = try #require(rawOccurrence)

        #expect(duration < .milliseconds(10), "Querying next occurrence took longer than expected: \(duration)")

        #expect(try occurrence.start == .withTestDate(hour: 12, minute: 35))

        var occurrences: [Occurrence] = []
        let duration2 = try clock.measure {
            occurrences = try schedule.nextOccurrences(in: .withTestDate(hour: 9, minute: 3)..., count: 2)
        }

        #expect(duration2 < .milliseconds(10), "Query next occurrences took longer than expected: \(duration2)")

        try #require(occurrences.count == 2)
        #expect(occurrences[0] == occurrence)

        let occurrence1 = occurrences[1]
        #expect(try occurrence1.start == .withTestDate(day: 25, hour: 12, minute: 35, second: 0))
    }

    @Test
    func dailyScheduleWithOneOccurrence() throws {
        let startDate: Date = try .withTestDate(hour: 9, minute: 23, second: 25)
        let schedule: Schedule = .daily(hour: 12, minute: 35, startingAt: startDate, end: .afterOccurrences(1), duration: .minutes(30))

        let occurrences = schedule.occurrences()
        var iterator = occurrences.makeIterator()

        let occurrence1 = try #require(iterator.next())
        #expect(try occurrence1.start == .withTestDate(hour: 12, minute: 35))
        #expect(try occurrence1.end == .withTestDate(hour: 13, minute: 5))

        #expect(iterator.next() == nil)
    }

    @Test
    func dailyScheduleWithOneOccurrenceSubSecondStartDate() throws {
        let startDate: Date = try .withTestDate(hour: 9, minute: 23, second: 25, nanosecond: 527)
        let schedule: Schedule = .daily(hour: 12, minute: 35, startingAt: startDate, end: .afterOccurrences(1), duration: .minutes(30))

        let occurrences = schedule.occurrences()
        var iterator = occurrences.makeIterator()

        let occurrence1 = try #require(iterator.next())
        #expect(try occurrence1.start == .withTestDate(hour: 12, minute: 35))
        #expect(try occurrence1.end == .withTestDate(hour: 13, minute: 5))

        #expect(iterator.next() == nil)
    }

    @Test
    func dailyScheduleWithThreeOccurrences() throws {
        let startDate: Date = try .withTestDate(hour: 9, minute: 23, second: 25)
        let schedule: Schedule = .daily(hour: 12, minute: 35, startingAt: startDate, end: .afterOccurrences(3), duration: .minutes(30))

        let occurrences = schedule.occurrences()
        var iterator = occurrences.makeIterator()

        let occurrence1 = try #require(iterator.next())
        #expect(try occurrence1.start == .withTestDate(hour: 12, minute: 35))
        #expect(try occurrence1.end == .withTestDate(hour: 13, minute: 5))

        let occurrence2 = try #require(iterator.next())
        #expect(try occurrence2.start == .withTestDate(day: 25, hour: 12, minute: 35))
        #expect(try occurrence2.end == .withTestDate(day: 25, hour: 13, minute: 5))

        let occurrence3 = try #require(iterator.next())
        #expect(try occurrence3.start == .withTestDate(day: 26, hour: 12, minute: 35))
        #expect(try occurrence3.end == .withTestDate(day: 26, hour: 13, minute: 5))

        #expect(iterator.next() == nil)
    }

    @Test
    func dailyScheduleWithDateEnd() throws {
        let startDate: Date = try .withTestDate(hour: 9, minute: 23, second: 25)
        let endDate = startDate.addingTimeInterval(Double(Duration.seconds(16 * 24 * 60 * 60).components.seconds))
        let schedule: Schedule = .weekly(
            weekday: .sunday,
            hour: 12,
            minute: 35,
            startingAt: startDate,
            end: .afterDate(endDate),
            duration: .minutes(30)
        )

        let occurrences = schedule.occurrences()
        var iterator = occurrences.makeIterator()

        let occurrence1 = try #require(iterator.next())
        #expect(try occurrence1.start == .withTestDate(day: 25, hour: 12, minute: 35))
        #expect(try occurrence1.end == .withTestDate(day: 25, hour: 13, minute: 5))

        let occurrence2 = try #require(iterator.next())
        #expect(try occurrence2.start == .withTestDate(month: 9, day: 1, hour: 12, minute: 35))
        #expect(try occurrence2.end == .withTestDate(month: 9, day: 1, hour: 13, minute: 5))

        let occurrence3 = try #require(iterator.next())
        #expect(try occurrence3.start == .withTestDate(month: 9, day: 8, hour: 12, minute: 35))
        #expect(try occurrence3.end == .withTestDate(month: 9, day: 8, hour: 13, minute: 5))

        #expect(iterator.next() == nil)
    }
}


extension Date {
    static func withTestDate(year: Int = 2024, month: Int = 8, day: Int = 24, hour: Int, minute: Int, second: Int = 0, nanosecond: Int = 0) throws -> Date {
        // swiftlint:disable:previous function_default_parameter_at_end line_length
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second, nanosecond: nanosecond)
        return try #require(Calendar.current.date(from: components))
    }
}
