//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@testable import Spezi
import SpeziLocalStorage
@testable import SpeziScheduler
import SpeziSecureStorage
import XCTest
import XCTSpezi


final class SchedulerTests: XCTestCase {
    private func createScheduler(withInitialTasks initialTasks: Task<String>) async throws -> Scheduler<String> {
        let scheduler = Scheduler<String>(tasks: [initialTasks])

        withDependencyResolution {
            scheduler
        }

        try? await _Concurrency.Task.sleep(for: .seconds(0.1)) // allow for configuration

        return scheduler
    }
    
    
    func testObservedObjectCalls() async throws {
        let numberOfEvents = 6
        
        let testTask = Task(
            title: "Test Task",
            description: "This is a Test task",
            schedule: Schedule(
                start: .now.addingTimeInterval(1),
                repetition: .matching(.init(nanosecond: 0)), // Every full second
                end: .numberOfEvents(numberOfEvents)
            ),
            context: "This is a test context"
        )
        let scheduler = try await createScheduler(withInitialTasks: testTask)

        try await _Concurrency.Task.sleep(for: .seconds(numberOfEvents + 3))

        let events = scheduler.tasks.flatMap { $0.events() }
        let completedEvents = events.filter { $0.complete }.count
        let uncompletedEvents = events.filter { !$0.complete }.count

        XCTAssertEqual(numberOfEvents, uncompletedEvents + completedEvents)
    }
    
    func testRandomSchedulerFunctionality() async throws {
        let numberOfEvents = 10
        
        let testTask = Task(
            title: "Random Scheduler Test Task",
            description: "Random Scheduler Test task",
            schedule: Schedule(
                start: .now.addingTimeInterval(1),
                repetition: .randomBetween( // Randomly scheduled in the first half of each second.
                    start: .init(nanosecond: 450_000_000),
                    end: .init(nanosecond: 550_000_000)
                                          ),
                end: .numberOfEvents(numberOfEvents)
            ),
            context: "This is a test context"
        )
        let scheduler = try await createScheduler(withInitialTasks: testTask)

        for event in scheduler.tasks.flatMap({ $0.events() }) {
            let nanosecondsElement = Calendar.current.dateComponents([.nanosecond], from: event.scheduledAt).nanosecond ?? 0
            XCTAssertGreaterThan(nanosecondsElement, 450_000_000)
            XCTAssertLessThan(nanosecondsElement, 550_000_000)
        }


        try await _Concurrency.Task.sleep(for: .seconds(numberOfEvents + 3))

        let events = scheduler.tasks.flatMap { $0.events() }
        let completedEvents = events.filter { $0.complete }.count
        let uncompletedEvents = events.filter { !$0.complete }.count

        XCTAssertEqual(numberOfEvents, uncompletedEvents + completedEvents)
    }
    
    
    func testCompleteEvents() async throws {
        let numberOfEvents = 6
        
        let testTask = Task(
            title: "Test Task",
            description: "This is a test task",
            schedule: Schedule(
                start: .now.addingTimeInterval(42_000),
                repetition: .matching(.init(nanosecond: 0)), // Every full second
                end: .numberOfEvents(numberOfEvents)
            ),
            context: "This is a test context"
        )
        let scheduler = try await createScheduler(withInitialTasks: testTask)

        try await _Concurrency.Task.sleep(for: .seconds(1))
        
        let testTask2 = Task(
            title: "Test Task 2",
            description: "This is a second test task",
            schedule: Schedule(
                start: .now.addingTimeInterval(42_000),
                repetition: .matching(.init(nanosecond: 0)), // Every full second
                end: .numberOfEvents(numberOfEvents)
            ),
            context: "This is a second test context"
        )
        await scheduler.schedule(task: testTask2)

        XCTAssertEqual(scheduler.tasks.count, 2)

        try await _Concurrency.Task.sleep(for: .seconds(1))

        let expectationCompleteEvents = XCTestExpectation(description: "Complete all events")
        expectationCompleteEvents.expectedFulfillmentCount = numberOfEvents * 2
        expectationCompleteEvents.assertForOverFulfill = true
        
        let events: Set<Event> = Set(scheduler.tasks.flatMap { $0.events() })
        _Concurrency.Task {
            for event in events {
                await event.complete(true)
                try? await _Concurrency.Task.sleep(for: .seconds(0.5))
                expectationCompleteEvents.fulfill()
            }
        }
        
        await fulfillment(of: [expectationCompleteEvents], timeout: (Double(numberOfEvents) * 2 * 0.5) + 3)

        XCTAssert(events.allSatisfy { $0.complete })
        XCTAssertEqual(events.count, 12)
    }
    
    func testCodable() throws {
        let tasks = [
            Task(
                title: "Test Task",
                description: "This is a test task",
                schedule: Schedule(
                    start: .now,
                    repetition: .matching(.init(nanosecond: 0)), // Every full second
                    end: .numberOfEvents(2)
                ),
                context: "This is a test context"
            ),
            Task(
                title: "Test Task 2",
                description: "This is a second test task",
                schedule: Schedule(
                    start: .now.addingTimeInterval(10),
                    repetition: .matching(.init(nanosecond: 0)), // Every full second
                    end: .numberOfEvents(2)
                ),
                context: "This is a second test context"
            )
        ]
        
        try encodeAndDecodeTasksAssertion(tasks)
        
        let expectation = XCTestExpectation(description: "Get Updates for all scheduled events.")
        expectation.expectedFulfillmentCount = 4
        expectation.assertForOverFulfill = true
        
        let events: Set<Event> = Set(tasks.flatMap { $0.events() })
        for event in events {
            _Concurrency.Task {
                await event.complete(true)
                expectation.fulfill()
            }
        }
        
        sleep(1)
        wait(for: [expectation], timeout: TimeInterval(2))
        
        XCTAssert(events.allSatisfy { $0.complete })
        XCTAssertEqual(events.count, 4)
        
        try encodeAndDecodeTasksAssertion(tasks)
    }
    
    private func encodeAndDecodeTasksAssertion(_ tasks: [Task<String>]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(tasks)
        let decodedTasks = try JSONDecoder().decode([Task<String>].self, from: data)
        XCTAssertEqual(tasks, decodedTasks)
    }

    func testLegacyEventDecoding() throws {
        let uuid = UUID()
        let date = Date().addingTimeInterval(100)

        let json =
        """
        {
            "scheduledAt": \(date.timeIntervalSinceReferenceDate),
            "notification": "\(uuid.uuidString)"
        }
        """

        let event = try JSONDecoder().decode(Event.self, from: Data(json.utf8))

        XCTAssertFalse(event.due)
        XCTAssertFalse(event.complete)
        XCTAssertEqual(event.notification, uuid)
        XCTAssertEqual(event.scheduledAt, date)
    }

    func testDueDecoding() throws {
        let date = Date().addingTimeInterval(-100)

        let json =
        """
        {
            "scheduledAt": \(date.timeIntervalSinceReferenceDate)
        }
        """

        let event = try JSONDecoder().decode(Event.self, from: Data(json.utf8))

        XCTAssertTrue(event.due)
        XCTAssertFalse(event.complete)
        XCTAssertEqual(event.scheduledAt, date)
    }

    func testCompletedDecoding() throws {
        let date = Date().addingTimeInterval(-100)
        let completed = Date().addingTimeInterval(-5)

        let json =
        """
        {
            "scheduledAt": \(date.timeIntervalSinceReferenceDate),
            "completedAt": \(completed.timeIntervalSinceReferenceDate)
        }
        """

        let event = try JSONDecoder().decode(Event.self, from: Data(json.utf8))

        XCTAssertFalse(event.due)
        XCTAssertTrue(event.complete)
        XCTAssertEqual(event.scheduledAt, date)
        XCTAssertEqual(event.completedAt, completed)
    }

    func testCurrentCalendarEncoding() throws {
        let json = """
        {
            "events": [],
            "notifications": false,
            "context": "This is a test context",
            "description": "This is a test task",
            "id": "DEDDE3FF-0A75-4A8C-9F0D-75AD417F1104",
            "schedule" : {
                "calendar": "current",
                "repetition" : {
                    "matching" : {
                        "_0" : {
                            "nanosecond" : 500000000
                        }
                    }
                },
                "end" : {
                    "numberOfEvents": {
                      "_0" : 42
                    }
                },
                "start" : 694224000
            },
            "title" : "Test Task"
        }
        """
        let task = try JSONDecoder().decode(Task<String>.self, from: Data(json.utf8))
        XCTAssertEqual(task.schedule.calendar, .current)
    }
}
