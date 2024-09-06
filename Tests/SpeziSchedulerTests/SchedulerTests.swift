//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziLocalStorage
@_spi(TestingSupport)
@testable import SpeziScheduler
import SpeziSecureStorage
import XCTest
import XCTSpezi

import SwiftUI // TODO: remove?

final class SchedulerTests: XCTestCase { // swiftlint:disable:this type_body_length
    @MainActor
    func testScheduler() {
        // test simple scheduler initialization test
        let module = ILScheduler()
        withDependencyResolution {
            module
        }

        let range = Date.today..<Date.now

        XCTAssertNoThrow(
            XCTAssert(try module.queryTasks(for: range).isEmpty),
            "Failed to perform task query on empty scheduler. Did configure fail?"
        )

        XCTAssertNoThrow(
            XCTAssert(try module.queryEvents(for: range).isEmpty),
            "Failed to perform task query on empty scheduler. Did configure fail?"
        )
    }

    @MainActor
    func testSimpleTaskCreation() throws {
        let module = ILScheduler()
        withDependencyResolution {
            module
        }

        let schedule: ILSchedule = .daily(hour: 8, minute: 35, startingAt: .today)

        let result = try module.createOrUpdateTask(
            id: "test-task",
            title: "Hello World",
            instructions: "Complete the Task!",
            schedule: schedule
        ) { context in
            context.example = "Additional Storage Stuff"
        }

        XCTAssertTrue(result.didChange)

        let results = try module.queryTasks(for: Date.yesterday..<Date.tomorrow)
        XCTAssertEqual(results.count, 1, "Received unexpected amount of tasks in query.")
        let task0 = try XCTUnwrap(results.first)

        XCTAssertIdentical(result.task, task0)

        // test that both overloads work as expected
        _ = task0.title as LocalizedStringResource
        _ = task0.title as String.LocalizationValue
        _ = task0.instructions as LocalizedStringResource
        _ = task0.instructions as String.LocalizationValue

        XCTAssertEqual(task0.id, "test-task")
        XCTAssertEqual(task0.example, "Additional Storage Stuff")
        XCTAssertEqual(task0.title, "Hello World")
    }

    @MainActor
    func testSimpleTaskVersioning() throws { // swiftlint:disable:this function_body_length
        let module = ILScheduler()
        withDependencyResolution {
            module
        }

        let start = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 6, hour: 14, minute: 0, second: 0)))
        let date0 = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 6, hour: 14, minute: 59, second: 49)))
        let date1 = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 6, hour: 15, minute: 59, second: 49)))
        let end = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 6, hour: 17, minute: 0, second: 0)))

        // a schedule that happens every hour at half past, starting from `date0`
        let schedule = ILSchedule(startingAt: date0, recurrence: .hourly(calendar: .current, minutes: [30]))

        let firstVersion = try module.createOrUpdateTask(
            id: "test-task",
            title: "Hello World",
            instructions: "Complete the Task!",
            schedule: schedule,
            effectiveFrom: date0
        ) { context in
            context.example = "Additional Storage Stuff"
        }

        XCTAssertTrue(firstVersion.didChange)
        XCTAssertNil(firstVersion.task.previousVersion)
        XCTAssertNil(firstVersion.task.nextVersion)

        let noChanges = try module.createOrUpdateTask(
            id: "test-task",
            title: "Hello World",
            instructions: "Complete the Task!",
            schedule: schedule,
            effectiveFrom: date0
        ) { context in
            context.example = "Additional Storage Stuff"
        }

        XCTAssertFalse(noChanges.didChange)

        let secondVersion = try module.createOrUpdateTask(
            id: "test-task",
            title: "Hello World 2",
            instructions: "Complete the task slightly differently!",
            schedule: schedule, // we use the same schedule, however date1 is after the start of the schedule, so previous versions stays responsible
            effectiveFrom: date1
        ) { context in
            context.example = "Additional Storage Stuff"
        }

        XCTAssertTrue(secondVersion.didChange)
        XCTAssertNil(secondVersion.task.nextVersion)
        XCTAssertIdentical(secondVersion.task.previousVersion, firstVersion.task)
        XCTAssertNil(firstVersion.task.previousVersion)
        XCTAssertIdentical(firstVersion.task.nextVersion, secondVersion.task)

        let results = try module.queryTasks(for: start...date1)
        continueAfterFailure = false
        XCTAssertEqual(results.count, 2, "Received unexpected amount of tasks in query.")
        continueAfterFailure = true
        let task0 = results[0]
        let task1 = results[1]

        XCTAssertEqual(try module.queryTasks(for: start..<date1).count, 1)

        // test implicit sort descriptor
        XCTAssertIdentical(task0, firstVersion.task)
        XCTAssertIdentical(task1, secondVersion.task)

        // test equality of fields
        XCTAssertEqual(task0, firstVersion.task)
        XCTAssertEqual(task1, secondVersion.task)


        let events = try module.queryEvents(for: start..<end)

        continueAfterFailure = false
        XCTAssertEqual(events.count, 2)
        continueAfterFailure = true

        // there should be two events.
        // The first one is still provided by the first version, as the second task version only become effective after `date1`
        // even if its schedule already starts from `date0`.

        let event0 = events[0]
        let event1 = events[1]

        XCTAssertIdentical(event0.task, firstVersion.task)
        XCTAssertIdentical(event1.task, secondVersion.task)

        XCTAssertNil(event0.outcome)
        XCTAssertNil(event1.outcome)

        let components0 = Calendar.current.dateComponents([.hour, .minute, .second], from: event0.occurrence.start)
        let components1 = Calendar.current.dateComponents([.hour, .minute, .second], from: event1.occurrence.start)

        XCTAssertEqual(components0.hour, 15)
        XCTAssertEqual(components0.minute, 30)
        XCTAssertEqual(components0.second, 49)

        XCTAssertEqual(components1.hour, 16)
        XCTAssertEqual(components1.minute, 30)
        XCTAssertEqual(components1.second, 49)
    }

    @MainActor
    func testSchedulerSampleData() throws {
        let container = try SchedulerSampleData.makeSharedContext()

        let scheduler = ILScheduler(testingContainer: container)
        withDependencyResolution {
            scheduler
        }

        let results = try scheduler.queryTasks(for: Date.yesterday..<Date.tomorrow)
        XCTAssertEqual(results.count, 1, "Received unexpected amount of tasks in query.")

        let events = try scheduler.queryEvents(for: Date.yesterday..<Date.tomorrow)
        print(events)
    }
}
