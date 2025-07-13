//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_length function_body_length file_types_order

import Spezi
@_spi(TestingSupport)
@testable import SpeziScheduler
import SpeziTesting
import SwiftData
import Testing
import XCTest
import XCTRuntimeAssertions


@Suite
@MainActor
struct SchedulerTests { // swiftlint:disable:this type_body_length
    /// What a test should do when it wants to delete all versions of a ``Task``.
    enum DeleteAllTaskVersionsApproach: CaseIterable {
        /// The test should delete the first (ie, oldest) version of the task, which then implicitly also ends up deleting the newer versions (ie, all other versions)
        case viaFirst
        /// The test should explicitly pass all task versions to the scheduler's deletion API.
        case allExplicitly
        /// The test should use ``Scheduler/deleteAllVersions(ofTask:)`` API.
        case viaId
    }
    
    
    @Test
    func scheduler() throws {
        // test simple scheduler initialization test
        let module = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            module
        }
        let range = Date.today..<Date.now
        #expect(try module.queryTasks(for: range).isEmpty, "Failed to perform task query on empty scheduler. Did configure fail?")
        #expect(try module.queryEvents(for: range).isEmpty, "Failed to perform task query on empty scheduler. Did configure fail?")
    }

    @Test
    func simpleTaskCreation() throws {
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

        #expect(result.didChange)

        let results = try module.queryTasks(for: Date.yesterday..<Date.tomorrow)
        #expect(results.count == 1, "Received unexpected amount of tasks in query.")
        let task0 = try #require(results.first)

        #expect(result.task === task0)

        // test that both overloads work as expected
        _ = task0.title as LocalizedStringResource
        _ = task0.title as String.LocalizationValue
        _ = task0.instructions as LocalizedStringResource
        _ = task0.instructions as String.LocalizationValue

        #expect(task0.id == "test-task")
        #expect(task0.example == "Additional Storage Stuff")
        #expect(task0.title == "Hello World")

        try module.deleteTasks(result.task)
    }

    @Test
    func simpleTaskVersioning() throws {
        let module = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            module
        }

        let start = try #require(Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 6, hour: 14, minute: 0, second: 0)))
        let date0 = try #require(Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 6, hour: 14, minute: 59, second: 49)))
        let date1 = try #require(Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 6, hour: 15, minute: 59, second: 49)))
        let end = try #require(Calendar.current.date(from: DateComponents(year: 2024, month: 9, day: 6, hour: 17, minute: 0, second: 0)))

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

        #expect(firstVersion.didChange)
        #expect(firstVersion.task.previousVersion == nil)
        #expect(firstVersion.task.nextVersion == nil)

        let noChanges = try module.createOrUpdateTask(
            id: "test-task",
            title: "Hello World",
            instructions: "Complete the Task!",
            schedule: schedule,
            effectiveFrom: date0
        ) { context in
            context.example = "Additional Storage Stuff"
        }

        #expect(!noChanges.didChange)

        let secondVersion = try module.createOrUpdateTask(
            id: "test-task",
            title: "Hello World 2",
            instructions: "Complete the task slightly differently!",
            schedule: schedule, // we use the same schedule, however date1 is after the start of the schedule, so previous versions stays responsible
            effectiveFrom: date1
        ) { context in
            context.example = "Additional Storage Stuff"
        }

        #expect(secondVersion.didChange)
        #expect(secondVersion.task.nextVersion == nil)
        #expect(secondVersion.task.previousVersion === firstVersion.task)
        #expect(firstVersion.task.previousVersion == nil)
        #expect(firstVersion.task.nextVersion === secondVersion.task)

        let results = try module.queryTasks(for: start...date1)
        try #require(results.count == 2, "Received unexpected amount of tasks in query.")
        let task0 = results[0]
        let task1 = results[1]

        #expect(try module.queryTasks(for: start..<date1).count == 1)

        // test implicit sort descriptor
        #expect(task0 === firstVersion.task)
        #expect(task1 === secondVersion.task)

        // test equality of fields
        #expect(task0 == firstVersion.task)
        #expect(task1 == secondVersion.task)


        let events = try module.queryEvents(for: start..<end)

        try #require(events.count == 2)

        // there should be two events.
        // The first one is still provided by the first version, as the second task version only become effective after `date1`
        // even if its schedule already starts from `date0`.

        let event0 = events[0]
        let event1 = events[1]

        #expect(event0.task === firstVersion.task)
        #expect(event1.task === secondVersion.task)

        #expect(event0.outcome == nil)
        #expect(event1.outcome == nil)

        let components0 = Calendar.current.dateComponents([.hour, .minute, .second], from: event0.occurrence.start)
        let components1 = Calendar.current.dateComponents([.hour, .minute, .second], from: event1.occurrence.start)

        #expect(components0.hour == 15)
        #expect(components0.minute == 30)
        #expect(components0.second == 49)

        #expect(components1.hour == 16)
        #expect(components1.minute == 30)
        #expect(components1.second == 49)

        try module.deleteAllVersions(ofTask: "test-task")
    }
    
    @Test
    func nonTrivialTaskContextCoding() throws {
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
        
        #expect(try createTask().didChange)
        #expect(try !createTask().didChange)
    }
    
    
    @Test
    func fetchingEventsAfterCompletion() async throws {
        let todayRange = Date.today..<Date.tomorrow
        let module = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            module
        }
        
        try module.eraseDatabase()
        #expect(try module.queryAllTasks().isEmpty)
        #expect(try module.queryAllOutcomes().isEmpty)
        #expect(try module.queryEvents(for: todayRange).isEmpty)
        
        let task = try module.createOrUpdateTask(
            id: "test-task",
            title: "Test Task",
            instructions: "",
            schedule: .daily(hour: 0, minute: 0, startingAt: .now)
        ).task
        
        let events = try module.queryEvents(for: todayRange)
        #expect(events.allSatisfy { todayRange.contains($0.occurrence.start) })
        #expect(events.count == 1)
        #expect(try !#require(events.first).isCompleted)
        try #require(events.first).complete()
        #expect(try #require(events.first).isCompleted)
        #expect(try #require(try module.queryEvents(for: todayRange).first).isCompleted)
        try await _Concurrency.Task.sleep(for: .seconds(0.5))
        #expect(try #require(try module.queryEvents(for: todayRange).first).isCompleted)
        do {
            let events1 = try module.queryEvents(for: task, in: todayRange)
            let events2 = try module.queryEvents(forTaskWithId: task.id, in: todayRange)
            #expect(events1.elementsEqual(events2) { lhs, rhs in
                lhs.task == rhs.task && lhs.occurrence == rhs.occurrence && lhs.isCompleted == rhs.isCompleted
            })
        }
    }
    
    
    @Test
    func deleteAllVersions() async throws {
        let module = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            module
        }
        try module.eraseDatabase()
        
        func addTask(_ id: String, schedule: Schedule) throws -> Task {
            try module.createOrUpdateTask(id: id, title: "", instructions: "", schedule: schedule, completionPolicy: .anytime).task
        }
        
        let task = try addTask("task", schedule: .daily(hour: 0, minute: 0, startingAt: .now))
        
        do {
            let events = try module.queryEvents(forTaskWithId: "task", in: Calendar.current.rangeOfDay(for: .now))
            #expect(events.count == 1)
            try #require(events.first).complete()
        }
        
        // update the task (this will create a new version)
        let task2 = try addTask("task", schedule: .daily(hour: 23, minute: 59, second: 59, startingAt: .now))
        #expect(task2 == task.nextVersion)
        #expect(task2.previousVersion == task)
        
        do {
            let events = try module.queryEvents(forTaskWithId: "task", in: Calendar.current.rangeOfDay(for: .now))
            #expect(events.count == 1)
            try #require(events.first).complete()
        }
        
        try module.deleteAllVersions(of: task2)
        
        #expect(try module.queryAllTasks().isEmpty)
    }
    
    
    @Test
    func deleteTaskSingleVersionNoOutcomes() async throws {
        let cal = Calendar.current
        let module = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            module
        }
        try module.eraseDatabase()
        
        @discardableResult
        func addTask(_ id: String, startingAt startDate: Date) throws -> Task {
            let (task, didChange) = try module.createOrUpdateTask(
                id: id,
                title: "",
                instructions: "",
                schedule: .daily(hour: 0, minute: 0, startingAt: startDate),
                completionPolicy: .anytime,
                effectiveFrom: startDate
            )
            #expect(didChange)
            return task
        }
        
        let task = try addTask("task", startingAt: cal.startOfMonth(for: .now))
        
        try module.deleteTasks(task)
        
        #expect(try module.queryAllTasks().isEmpty)
        #expect(try module.queryAllOutcomes().isEmpty)
    }
    
    
    @Test
    func deleteTaskSingleVersionSomeOutcomes() async throws {
        let cal = Calendar.current
        let module = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            module
        }
        try module.eraseDatabase()
        
        @discardableResult
        func addTask(_ id: String, startingAt startDate: Date) throws -> Task {
            let (task, didChange) = try module.createOrUpdateTask(
                id: id,
                title: "",
                instructions: "",
                schedule: .daily(hour: 0, minute: 0, startingAt: startDate),
                completionPolicy: .anytime,
                effectiveFrom: startDate
            )
            #expect(didChange)
            return task
        }
        
        let task = try addTask("task", startingAt: cal.startOfMonth(for: .now))
        
        for event in try module.queryEvents(for: cal.rangeOfMonth(for: .now)) {
            try event.complete()
        }
        
        #expect(try module.queryAllTasks() == [task])
        #expect(try module.queryAllOutcomes().count == cal.numberOfDaysInMonth(for: .now))
        
        try module.deleteTasks(task)
        
        #expect(try module.queryAllTasks().isEmpty)
        #expect(try module.queryAllOutcomes().isEmpty)
    }
    
    
    @Test(arguments: DeleteAllTaskVersionsApproach.allCases)
    func deleteTaskMultipleVersionsNoOutcomes(deleteAllVersionsApproach: DeleteAllTaskVersionsApproach) async throws {
        let cal = Calendar.current
        let module = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            module
        }
        try module.eraseDatabase()
        
        @discardableResult
        func addTask(_ id: String, startingAt startDate: Date) throws -> Task {
            let (task, didChange) = try module.createOrUpdateTask(
                id: id,
                title: "",
                instructions: "",
                schedule: .daily(hour: 0, minute: 0, startingAt: startDate),
                completionPolicy: .anytime,
                effectiveFrom: startDate
            )
            #expect(didChange)
            return task
        }
        
        let taskV1 = try addTask("task", startingAt: cal.startOfMonth(for: .now))
        let taskV2 = try addTask("task", startingAt: cal.startOfNextMonth(for: .now))
        
        #expect(try Set(module.queryAllTasks()) == [taskV1, taskV2])
        #expect(try module.queryAllOutcomes().isEmpty)
        
        switch deleteAllVersionsApproach {
        case .viaFirst:
            try module.deleteTasks(taskV1)
        case .allExplicitly:
            try module.deleteTasks([taskV1, taskV2])
        case .viaId:
            try module.deleteAllVersions(ofTask: "task")
        }
        #expect(try module.queryAllTasks().isEmpty)
        #expect(try module.queryAllOutcomes().isEmpty)
    }
    
    
    @Test(arguments: DeleteAllTaskVersionsApproach.allCases)
    func deleteTaskMultipleVersionsSomeOutcomes(deleteAllVersionsApproach: DeleteAllTaskVersionsApproach) async throws {
        let cal = Calendar.current
        let module = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            module
        }
        try module.eraseDatabase()
        
        @discardableResult
        func addTask(_ id: String, title: String, startingAt startDate: Date) throws -> Task {
            let (task, didChange) = try module.createOrUpdateTask(
                id: id,
                title: "\(title)",
                instructions: "",
                schedule: .daily(hour: 0, minute: 0, startingAt: startDate),
                completionPolicy: .anytime,
                effectiveFrom: startDate
            )
            #expect(didChange)
            return task
        }
        
        let taskV1 = try addTask("task", title: "V1", startingAt: cal.startOfMonth(for: .now))
        for event in try module.queryEvents(for: cal.rangeOfMonth(for: .now)) {
            try event.complete()
        }
        
        let taskV2 = try addTask("task", title: "V2", startingAt: cal.startOfNextMonth(for: .now))
        for event in try module.queryEvents(for: cal.rangeOfMonth(for: cal.startOfNextMonth(for: .now))) {
            try event.complete()
        }
        
        #expect(try Set(module.queryAllTasks()) == [taskV1, taskV2])
        #expect(try module.queryAllOutcomes().count == cal.numberOfDaysInMonth(for: .now) + cal.numberOfDaysInMonth(for: cal.startOfNextMonth(for: .now))) // swiftlint:disable:this line_length
        
        try module.deleteTasks(taskV1)
        switch deleteAllVersionsApproach {
        case .viaFirst:
            try module.deleteTasks(taskV1)
        case .allExplicitly:
            try module.deleteTasks([taskV1, taskV2])
        case .viaId:
            try module.deleteAllVersions(ofTask: "task")
        }
        #expect(try module.queryAllTasks().isEmpty)
        #expect(try module.queryAllOutcomes().isEmpty)
    }
    
    
    @Test(arguments: DeleteAllTaskVersionsApproach.allCases)
    func deleteTask(deleteAllVersionsApproach: DeleteAllTaskVersionsApproach) async throws {
        let cal = Calendar.current
        let module = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            module
        }
        try module.eraseDatabase()
        
        @discardableResult
        func addTask(_ id: String, startingAt startDate: Date) throws -> Task {
            let (task, didChange) = try module.createOrUpdateTask(
                id: id,
                title: "",
                instructions: "",
                schedule: .daily(hour: 0, minute: 0, startingAt: startDate),
                completionPolicy: .anytime,
                effectiveFrom: startDate
            )
            #expect(didChange)
            return task
        }
        
        try addTask("task", startingAt: cal.startOfMonth(for: .now))
        
        for idx in 0..<12 {
            let task = try #require(module.queryAllTasks().max { $1.effectiveFrom > $0.effectiveFrom })
            let timeRange = cal.rangeOfMonth(for: task.schedule.start)
            for event in try module.queryEvents(for: task, in: timeRange) {
                try event.complete()
            }
            for event in try module.queryEvents(for: task, in: timeRange) {
                #expect(event.isCompleted)
            }
            // we expect one outcome per day.
            #expect(try module.queryAllOutcomes().count == (0...idx)
                    .map { try #require(cal.date(byAdding: .month, value: $0, to: cal.startOfMonth(for: .now))) }
                    .map { cal.numberOfDaysInMonth(for: $0) }
                    .reduce(0, +)
            )
            try addTask("task", startingAt: cal.startOfNextMonth(for: task.schedule.start))
        }
        
        let allTasks = try module.queryAllTasks().sorted(using: KeyPathComparator(\.effectiveFrom))
        
        switch deleteAllVersionsApproach {
        case .viaFirst:
            try module.deleteTasks(try #require(allTasks.first))
        case .allExplicitly:
            try module.deleteTasks(allTasks.shuffled())
        case .viaId:
            try module.deleteAllVersions(ofTask: "task")
        }
        #expect(try module.queryAllTasks().isEmpty)
        #expect(try module.queryAllOutcomes().isEmpty)
    }
    
    
    // Ensures that the state of the Scheduler's underlying ModelContext is correct when performing multiple operations within a single
    // run loop iteration, i.e. before the context is saved.
    // See also: FB17583572 and FB18429335.
    @Test(arguments: [false, true])
    func schedulerFastModelContextOperations(useAlternativeDelete: Bool) throws {
        let module = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            module
        }
        try module.eraseDatabase()
        
        let (task1A, didCreateTask1A) = try module.createOrUpdateTask(
            id: "task1",
            title: "",
            instructions: "",
            schedule: .daily(hour: 0, minute: 0, startingAt: .now.addingTimeInterval(-1000)),
            effectiveFrom: .now.addingTimeInterval(-1000)
        )
        #expect(didCreateTask1A)
        #expect(try module.queryTasks(for: Calendar.current.rangeOfDay(for: .today)) == [task1A])
        
        let (task1B, didCreateTask1B) = try module.createOrUpdateTask(
            id: "task1",
            title: "",
            instructions: "",
            schedule: .daily(hour: 1, minute: 0, startingAt: .now)
        )
        #expect(didCreateTask1B)
        #expect(try module.queryTasks(for: Calendar.current.rangeOfDay(for: .today)).count == 2)
        #expect(try module.queryTasks(for: Calendar.current.rangeOfDay(for: .today)) == [task1A, task1B])
        
        let context = try module.context
        #expect(context.hasChanges)
        #expect(try context.fetchCount(FetchDescriptor<Task>()) == 2)
        
        #expect(try context.fetchCount(FetchDescriptor<Task>()) == 2)
        #expect(context.hasChanges)
        try context.save()
        #expect(!context.hasChanges)
        if useAlternativeDelete {
            try context.delete(model: Task.self)
            // testing for this behaviour, bc some of our code was changed to work around it
            // (eg the forceSave flag in the Scheduler's deferred-save API), and we might be able to
            // somplify some things once apple fixed this (and it's fixed on all platforms&versions we support!)
            #expect(!context.hasChanges) // should probably be true, but isn't (FB17583572)
        } else {
            for model in try context.fetch(FetchDescriptor<Task>()) {
                context.delete(model)
            }
            #expect(context.hasChanges)
        }
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Task>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Task>()) == 0)
    }
    
    // regression test around a bug where the context save would take place too late
    // and the notification scheduling would end up accessing an old state of the context, and crash.
    // was likely in part caused by using `ModelContext.delete(model:where:)` instead of `ModelContext.delete(_:)`.
    @Test
    func deleteTaskWithNotifications() async throws {
        let allTime = Date.distantPast...Date.distantFuture
        let scheduler = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            scheduler
        }
        let task = try scheduler.createOrUpdateTask(
            id: "task-1",
            title: "",
            instructions: "",
            schedule: .daily(hour: 23, minute: 59, startingAt: .now),
            scheduleNotifications: true,
            notificationThread: .global
        ).task
        try scheduler.deleteAllVersions(of: task)
        try #expect(scheduler.queryTasks(for: allTime).isEmpty)
    }
    
    @Test
    func hourlyTask() throws {
        let cal = Calendar.current
        let scheduler = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            scheduler
        }
        let startDate = cal.startOfHour(for: .now)
        _ = try scheduler.createOrUpdateTask(
            id: "hourlyTask",
            title: "",
            instructions: "",
            schedule: .hourly(minute: 59, second: 59, startingAt: startDate),
            effectiveFrom: startDate
        )
        let endDate = try #require(cal.date(byAdding: .day, value: 3, to: startDate))
        let events = try scheduler.queryEvents(for: startDate..<endDate)
        #expect(events.count == 72)
        let expectedDates = Array(cal.dates(
            byMatching: DateComponents(minute: 59, second: 59),
            startingAt: startDate,
            in: startDate..<endDate
        ))
        #expect(expectedDates.count == 72)
        for (event, expectedDate) in zip(events, expectedDates) {
            #expect(cal.component(.minute, from: event.occurrence.start) == 59)
            #expect(cal.component(.second, from: event.occurrence.start) == 59)
            #expect(event.occurrence.start == expectedDate)
        }
    }
    
    @Test
    func hourlyTask12HourInterval() throws {
        let cal = Calendar.current
        let scheduler = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            scheduler
        }
        let startDate = try #require(cal.date(from: .init(year: 2025, month: 7, day: 11, hour: 8)))
        _ = try scheduler.createOrUpdateTask(
            id: "12hourlyTask",
            title: "",
            instructions: "",
            schedule: .hourly(interval: 12, minute: 0, startingAt: startDate),
            effectiveFrom: startDate
        )
        let expectedDates: [Date] = [
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 11, hour: 8))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 11, hour: 20))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 12, hour: 8))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 12, hour: 20))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 13, hour: 8))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 13, hour: 20))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 14, hour: 8))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 14, hour: 20))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 15, hour: 8))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 15, hour: 20))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 16, hour: 8))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 16, hour: 20))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 17, hour: 8))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 17, hour: 20))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 18, hour: 8))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 18, hour: 20))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 19, hour: 8))),
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 19, hour: 20)))
        ]
        let events = try scheduler.queryEvents(for: startDate..<(try #require(expectedDates.last)).addingTimeInterval(1))
        #expect(events.count == expectedDates.count)
        for (event, expectedDate) in zip(events, expectedDates) {
            #expect(event.occurrence.start == expectedDate)
        }
    }
    
    @Test
    func monthlyTask() throws {
        let cal = Calendar.current
        let scheduler = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            scheduler
        }
        let startDate = try #require(cal.date(from: .init(year: 2025, month: 7, day: 11, hour: 8)))
        _ = try scheduler.createOrUpdateTask(
            id: "12hourlyTask",
            title: "",
            instructions: "",
            schedule: .monthly(day: 12, hour: 0, minute: 0, startingAt: startDate),
            effectiveFrom: startDate
        )
        let expectedDates: [Date] = [
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 12))),
            try #require(cal.date(from: .init(year: 2025, month: 8, day: 12))),
            try #require(cal.date(from: .init(year: 2025, month: 9, day: 12))),
            try #require(cal.date(from: .init(year: 2025, month: 10, day: 12))),
            try #require(cal.date(from: .init(year: 2025, month: 11, day: 12))),
            try #require(cal.date(from: .init(year: 2025, month: 12, day: 12))),
            try #require(cal.date(from: .init(year: 2026, month: 1, day: 12))),
            try #require(cal.date(from: .init(year: 2026, month: 2, day: 12))),
            try #require(cal.date(from: .init(year: 2026, month: 3, day: 12))),
            try #require(cal.date(from: .init(year: 2026, month: 4, day: 12))),
            try #require(cal.date(from: .init(year: 2026, month: 5, day: 12))),
            try #require(cal.date(from: .init(year: 2026, month: 6, day: 12))),
            try #require(cal.date(from: .init(year: 2026, month: 7, day: 12))),
            try #require(cal.date(from: .init(year: 2026, month: 8, day: 12))),
            try #require(cal.date(from: .init(year: 2026, month: 9, day: 12))),
            try #require(cal.date(from: .init(year: 2026, month: 10, day: 12))),
            try #require(cal.date(from: .init(year: 2026, month: 11, day: 12))),
            try #require(cal.date(from: .init(year: 2026, month: 12, day: 12))),
            try #require(cal.date(from: .init(year: 2027, month: 1, day: 12))),
            try #require(cal.date(from: .init(year: 2027, month: 2, day: 12)))
        ]
        let events = try scheduler.queryEvents(for: startDate..<(try #require(expectedDates.last)).addingTimeInterval(1))
        #expect(events.count == expectedDates.count)
        for (event, expectedDate) in zip(events, expectedDates) {
            #expect(event.occurrence.start == expectedDate)
        }
    }
    
    @Test
    func monthlyTask3MonthInterval() throws {
        let cal = Calendar.current
        let scheduler = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            scheduler
        }
        let startDate = try #require(cal.date(from: .init(year: 2025, month: 7, day: 2)))
        _ = try scheduler.createOrUpdateTask(
            id: "3monthlyTask",
            title: "",
            instructions: "",
            schedule: .monthly(interval: 3, day: 7, hour: 0, minute: 0, startingAt: startDate),
            effectiveFrom: startDate
        )
        let expectedDates: [Date] = [
            try #require(cal.date(from: .init(year: 2025, month: 7, day: 7))),
            try #require(cal.date(from: .init(year: 2025, month: 10, day: 7))),
            try #require(cal.date(from: .init(year: 2026, month: 1, day: 7))),
            try #require(cal.date(from: .init(year: 2026, month: 4, day: 7))),
            try #require(cal.date(from: .init(year: 2026, month: 7, day: 7))),
            try #require(cal.date(from: .init(year: 2026, month: 10, day: 7))),
            try #require(cal.date(from: .init(year: 2027, month: 1, day: 7))),
            try #require(cal.date(from: .init(year: 2027, month: 4, day: 7))),
            try #require(cal.date(from: .init(year: 2027, month: 7, day: 7))),
            try #require(cal.date(from: .init(year: 2027, month: 10, day: 7))),
            try #require(cal.date(from: .init(year: 2028, month: 1, day: 7))),
            try #require(cal.date(from: .init(year: 2028, month: 4, day: 7))),
            try #require(cal.date(from: .init(year: 2028, month: 7, day: 7)))
        ]
        let events = try scheduler.queryEvents(for: startDate..<(try #require(expectedDates.last)).addingTimeInterval(1))
        #expect(events.count == expectedDates.count)
        for (event, expectedDate) in zip(events, expectedDates) {
            #expect(event.occurrence.start == expectedDate)
        }
    }
    
    @Test
    func yearlyTask() throws {
        let cal = Calendar.current
        let scheduler = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            scheduler
        }
        let startDate = try #require(cal.date(from: .init(year: 2025, month: 7, day: 11, hour: 8)))
        _ = try scheduler.createOrUpdateTask(
            id: "12hourlyTask",
            title: "",
            instructions: "",
            schedule: .yearly(month: 11, day: 11, hour: 11, minute: 11, second: 11, startingAt: startDate),
            effectiveFrom: startDate
        )
        let expectedDates: [Date] = [
            try #require(cal.date(from: .init(year: 2025, month: 11, day: 11, hour: 11, minute: 11, second: 11))),
            try #require(cal.date(from: .init(year: 2026, month: 11, day: 11, hour: 11, minute: 11, second: 11))),
            try #require(cal.date(from: .init(year: 2027, month: 11, day: 11, hour: 11, minute: 11, second: 11))),
            try #require(cal.date(from: .init(year: 2028, month: 11, day: 11, hour: 11, minute: 11, second: 11))),
            try #require(cal.date(from: .init(year: 2029, month: 11, day: 11, hour: 11, minute: 11, second: 11))),
            try #require(cal.date(from: .init(year: 2030, month: 11, day: 11, hour: 11, minute: 11, second: 11))),
            try #require(cal.date(from: .init(year: 2031, month: 11, day: 11, hour: 11, minute: 11, second: 11))),
            try #require(cal.date(from: .init(year: 2032, month: 11, day: 11, hour: 11, minute: 11, second: 11)))
        ]
        let events = try scheduler.queryEvents(for: startDate..<(try #require(expectedDates.last)).addingTimeInterval(1))
        #expect(events.count == expectedDates.count)
        for (event, expectedDate) in zip(events, expectedDates) {
            #expect(event.occurrence.start == expectedDate)
        }
    }
    
    @Test
    func yearlyTask3YearInterval() throws {
        let cal = Calendar.current
        let scheduler = Scheduler(persistence: .inMemory)
        withDependencyResolution {
            scheduler
        }
        let startDate = try #require(cal.date(from: .init(year: 2025, month: 1, day: 2)))
        _ = try scheduler.createOrUpdateTask(
            id: "3monthlyTask",
            title: "",
            instructions: "",
            schedule: .yearly(interval: 3, month: 2, day: 1, hour: 0, minute: 0, startingAt: startDate),
            effectiveFrom: startDate
        )
        let expectedDates: [Date] = [
            try #require(cal.date(from: .init(year: 2025, month: 2, day: 1))),
            try #require(cal.date(from: .init(year: 2028, month: 2, day: 1))),
            try #require(cal.date(from: .init(year: 2031, month: 2, day: 1))),
            try #require(cal.date(from: .init(year: 2034, month: 2, day: 1))),
            try #require(cal.date(from: .init(year: 2037, month: 2, day: 1))),
            try #require(cal.date(from: .init(year: 2040, month: 2, day: 1))),
            try #require(cal.date(from: .init(year: 2043, month: 2, day: 1))),
            try #require(cal.date(from: .init(year: 2046, month: 2, day: 1))),
            try #require(cal.date(from: .init(year: 2049, month: 2, day: 1))),
            try #require(cal.date(from: .init(year: 2052, month: 2, day: 1)))
        ]
        let events = try scheduler.queryEvents(for: startDate..<(try #require(expectedDates.last)).addingTimeInterval(1))
        #expect(events.count == expectedDates.count)
        for (event, expectedDate) in zip(events, expectedDates) {
            #expect(event.occurrence.start == expectedDate)
        }
    }
}


final class OtherSchedulerTests: XCTestCase {
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
