//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
@_spi(TestingSupport)
@testable import SpeziScheduler
import XCTest
import XCTRuntimeAssertions
import XCTSpezi


final class SchedulerTests: XCTestCase {
    @MainActor
    func testScheduler() {
        // test simple scheduler initialization test
        let module = Scheduler(persistence: .inMemory)
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
        let module = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            module
        }

        let schedule: Schedule = .daily(hour: 8, minute: 35, startingAt: .today)

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

        XCTAssertNoThrow(try module.deleteTasks(result.task))
    }

    @MainActor
    func testSimpleTaskVersioning() throws { // swiftlint:disable:this function_body_length
        let module = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            module
        }

        let start = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 6, hour: 14, minute: 0, second: 0)))
        let date0 = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 6, hour: 14, minute: 59, second: 49)))
        let date1 = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 6, hour: 15, minute: 59, second: 49)))
        let end = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 6, hour: 17, minute: 0, second: 0)))

        // a schedule that happens every hour at half past, starting from `date0`
        let schedule = Schedule(startingAt: date0, recurrence: .hourly(calendar: .current, minutes: [30]))

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

        XCTAssertNoThrow(try module.deleteAllVersions(ofTask: "test-task"))
    }
    
    @MainActor
    func testNonTrivialTaskContextCoding() throws {
        let module = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            module
        }
        
        let value = NonTrivialTaskContext(
            field0: .random(in: 0..<100),
            field1: .random(in: 0..<100),
            field2: .random(in: 0..<100),
            field3: .random(in: 0..<100),
            field4: .random(in: 0..<100),
            field5: .random(in: 0..<100),
            field6: .random(in: 0..<100),
            field7: .random(in: 0..<100),
            field8: .random(in: 0..<100),
            field9: .random(in: 0..<100)
        )
        
        let createTask = {
            try module.createOrUpdateTask(
                id: #function,
                title: "Title",
                instructions: "Instructions",
                schedule: Schedule.daily(hour: 7, minute: 41, startingAt: .now),
                with: { context in
                    context.nonTrivialExample = value
                }
            )
        }
        
        XCTAssertTrue(try createTask().didChange)
        XCTAssertFalse(try createTask().didChange)
    }
    
    
    @MainActor
    func testFetchingEventsAfterCompletion() async throws {
        let todayRange = Date.today..<Date.tomorrow
        let module = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            module
        }
        
        try module.eraseDatabase()
        XCTAssertTrue(try module.queryAllTasks().isEmpty)
        XCTAssertTrue(try module.queryAllOutcomes().isEmpty)
        XCTAssertTrue(try module.queryEvents(for: todayRange).isEmpty)
        
        let task = try module.createOrUpdateTask(
            id: "test-task",
            title: "Test Task",
            instructions: "",
            schedule: .daily(hour: 0, minute: 0, startingAt: .now)
        ).task
        
        let events = try module.queryEvents(for: todayRange)
        XCTAssertTrue(events.allSatisfy { todayRange.contains($0.occurrence.start) })
        XCTAssertEqual(events.count, 1)
        XCTAssertFalse(try XCTUnwrap(events.first).isCompleted)
        try XCTUnwrap(events.first).complete()
        XCTAssertTrue(try XCTUnwrap(events.first).isCompleted)
        XCTAssertTrue(try XCTUnwrap(try module.queryEvents(for: todayRange).first).isCompleted)
        try await _Concurrency.Task.sleep(for: .seconds(0.5))
        XCTAssertTrue(try XCTUnwrap(try module.queryEvents(for: todayRange).first).isCompleted)
        do {
            let events1 = try module.queryEvents(for: task, in: todayRange)
            let events2 = try module.queryEvents(forTaskWithId: task.id, in: todayRange)
            XCTAssertTrue(events1.elementsEqual(events2) { lhs, rhs in
                lhs.task == rhs.task && lhs.occurrence == rhs.occurrence && lhs.isCompleted == rhs.isCompleted
            })
        }
    }
    
    
    @MainActor
    func testDeleteAllVersions() async throws {
        func waitABit() async throws {
            // to give it some time to save everything
            try await _Concurrency.Task.sleep(for: .seconds(0.25))
        }
        
        let module = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            module
        }
        try module.eraseDatabase()
        
        func addTask(_ id: String, schedule: Schedule) throws -> Task {
            try module.createOrUpdateTask(id: id, title: "", instructions: "", schedule: schedule, completionPolicy: .anytime).task
        }
        
        let task = try addTask("task", schedule: .daily(hour: 0, minute: 0, startingAt: .now))
        try await waitABit()
        
        do {
            let events = try module.queryEvents(forTaskWithId: "task", in: Calendar.current.rangeOfDay(for: .now))
            XCTAssertEqual(events.count, 1)
            try XCTUnwrap(events.first).complete()
        }
        try await waitABit()
        
        // update the task (this will create a new version)
        let task2 = try addTask("task", schedule: .daily(hour: 23, minute: 59, second: 59, startingAt: .now))
        try await waitABit()
        XCTAssertEqual(task2, task.nextVersion)
        XCTAssertEqual(task2.previousVersion, task)
        
        do {
            let events = try module.queryEvents(forTaskWithId: "task", in: Calendar.current.rangeOfDay(for: .now))
            XCTAssertEqual(events.count, 1)
            try XCTUnwrap(events.first).complete()
        }
        try await waitABit()
        
        try module.deleteAllVersions(ofTask: "task")
        try await waitABit()
        
        XCTAssert(try module.queryAllTasks().isEmpty)
    }
    
    
    @MainActor
    func testSandboxDetection() throws {
        #if os(macOS) || targetEnvironment(macCatalyst)
        // we expect this to fail, since we're on macOS and the unit tests are not sandboxed
        XCTAssertRuntimePrecondition { @Sendable in
            _ = Scheduler(persistence: .onDisk)
        }
        #else
        // we expect this not to fail, since we're in a non-macOS (ie, sandboxed) environment
        XCTAssertNoRuntimePrecondition { @Sendable in
            _ = Scheduler(persistence: .onDisk)
        }
        #endif
    }
}
