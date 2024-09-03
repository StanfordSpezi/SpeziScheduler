//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@testable import SpeziScheduler
import XCTest
import XCTSpezi


final class ScheduleTests: XCTestCase {
    func testOnceSchedule() throws {
        let startDate: Date = try .withTestDate(hour: 9, minute: 23, second: 25)
        let schedule: ILSchedule = .once(at: startDate, duration: .hours(2))

        let occurrences = schedule.occurrences()
        var iterator = occurrences.makeIterator()

        let occurrence1 = try XCTUnwrap(iterator.next())
        try XCTAssertEqual(occurrence1.start, .withTestDate(hour: 9, minute: 23, second: 25))
        try XCTAssertEqual(occurrence1.end, .withTestDate(hour: 11, minute: 23, second: 25))

        XCTAssertNil(iterator.next())
    }

    func testDailyScheduleWithThreeOccurrences() throws {
        let startDate: Date = try .withTestDate(hour: 9, minute: 23, second: 25)
        let schedule: ILSchedule = .daily(hour: 12, minute: 35, startingAt: startDate, end: .afterOccurrences(3), duration: .minutes(30))

        let occurrences = schedule.occurrences()
        var iterator = occurrences.makeIterator()

        let occurrence1 = try XCTUnwrap(iterator.next())
        try XCTAssertEqual(occurrence1.start, .withTestDate(hour: 12, minute: 35))
        try XCTAssertEqual(occurrence1.end, .withTestDate(hour: 13, minute: 5))

        let occurrence2 = try XCTUnwrap(iterator.next())
        try XCTAssertEqual(occurrence2.start, .withTestDate(day: 25, hour: 12, minute: 35))
        try XCTAssertEqual(occurrence2.end, .withTestDate(day: 25, hour: 13, minute: 5))

        let occurrence3 = try XCTUnwrap(iterator.next())
        try XCTAssertEqual(occurrence3.start, .withTestDate(day: 26, hour: 12, minute: 35))
        try XCTAssertEqual(occurrence3.end, .withTestDate(day: 26, hour: 13, minute: 5))

        XCTAssertNil(iterator.next())
    }

    func testDailyScheduleWithDateEnd() throws {
        let startDate: Date = try .withTestDate(hour: 9, minute: 23, second: 25)
        let endDate = startDate.addingTimeInterval(Double(Duration.seconds(16 * 24 * 60 * 60).components.seconds))
        let schedule: ILSchedule = .weekly(
            weekday: .sunday,
            hour: 12,
            minute: 35,
            startingAt: startDate,
            end: .afterDate(endDate),
            duration: .minutes(30)
        )

        let occurrences = schedule.occurrences()
        var iterator = occurrences.makeIterator()

        let occurrence1 = try XCTUnwrap(iterator.next())
        try XCTAssertEqual(occurrence1.start, .withTestDate(day: 25, hour: 12, minute: 35))
        try XCTAssertEqual(occurrence1.end, .withTestDate(day: 25, hour: 13, minute: 5))

        let occurrence2 = try XCTUnwrap(iterator.next())
        try XCTAssertEqual(occurrence2.start, .withTestDate(month: 9, day: 1, hour: 12, minute: 35))
        try XCTAssertEqual(occurrence2.end, .withTestDate(month: 9, day: 1, hour: 13, minute: 5))

        let occurrence3 = try XCTUnwrap(iterator.next())
        try XCTAssertEqual(occurrence3.start, .withTestDate(month: 9, day: 8, hour: 12, minute: 35))
        try XCTAssertEqual(occurrence3.end, .withTestDate(month: 9, day: 8, hour: 13, minute: 5))

        XCTAssertNil(iterator.next())
    }
}


extension Date {
    static func withTestDate(year: Int = 2024, month: Int = 8, day: Int = 24, hour: Int, minute: Int, second: Int = 0) throws -> Date {
        // swiftlint:disable:previous function_default_parameter_at_end
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        return try XCTUnwrap(Calendar.current.date(from: components), "Invalid test date")
    }
}
