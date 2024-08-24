//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SwiftData
import SwiftUI


public final class ILScheduler: Module {
    public enum DataError: Error { // TODO: localized errors?
        case invalidContainer
    }

    @Application(\.logger)
    private var logger

    private var _container: ModelContainer?

    private var container: ModelContainer {
        get throws {
            guard let container = _container else {
                throw DataError.invalidContainer
            }
            return container
        }
    }

    public init() {}

    public func configure() {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true) // TODO: only for tests
        do {
            _container = try ModelContainer(for: ILTask.self, Outcome.self, configurations: configuration)
        } catch {
            logger.error("Failed to initializer scheduler model container: \(error)")
        }
    }

    public func hasTasksConfigured(ids: String...) throws -> Bool {
        let container = try container

        let set = Set(ids)

        let descriptor = FetchDescriptor<ILTask>(
            predicate: #Predicate { task in
                set.contains(task.id)
            }
        )

        // TODO: not always create a context? what is smarter?
        let context = ModelContext(container)
        return try context.fetchCount(descriptor) == ids.count // TODO: forward errors?
    }

    // TODO: best way to configure initial tasks?
    public func addTasks(_ tasks: ILTask...) {
        self.addTasks(tasks)
    }

    public func deleteTasks(_ tasks: ILTask...) {
        self.deleteTasks(tasks)
    }


    public func addTasks(_ tasks: [ILTask]) {
        guard let container = try? container else {
            logger.error("Failed to persist tasks as container failed to be configured: \(tasks.map { $0.id }.joined(separator: ", "))")
            return
        }
        let context = ModelContext(container)

        for task in tasks {
            context.insert(task)
        }
    }

    public func deleteTasks(_ tasks: [ILTask]) {
        guard let container = try? container else {
            logger.error("Failed to delete tasks as container failed to be configured: \(tasks.map { $0.id }.joined(separator: ", "))")
            return
        }

        let context = ModelContext(container)

        for task in tasks {
            context.delete(task)
        }
    }

    public func queryTasks(for interval: DateInterval) throws -> [ILTask] {
        try self.queryTasks(for: interval.start...interval.end)
    }

    public func queryTasks(for range: ClosedRange<Date>) throws -> [ILTask] {
        let inClosedRangePredicate = #Predicate<ILTask> { task in
            if let effectiveTo = task.nextVersion?.effectiveFrom {
                // TODO: this currently doesn't do anything if the range is place in the middle of both!
                range.contains(task.effectiveFrom)
                    || (range.lowerBound <= effectiveTo && effectiveTo < range.upperBound)
            } else {
                // this is the latest version, so check if the effective
                task.effectiveFrom <= range.upperBound
            }
        }

        return try queryTask(with: inClosedRangePredicate)
    }


    // TODO: support RangeThroughs?
    public func queryTasks(for range: Range<Date>) throws -> [ILTask] {
        let inRangePredicate = #Predicate<ILTask> { task in
            if let effectiveTo = task.nextVersion?.effectiveFrom {
                range.contains(task.effectiveFrom)
                    || (range.lowerBound <= effectiveTo && effectiveTo <= range.upperBound)
            } else {
                task.effectiveFrom < range.upperBound
            }
        }

        return try queryTask(with: inRangePredicate)
    }

    private func queryTask(with predicate: Predicate<ILTask>) throws -> [ILTask] {
        let container = try container
        let context = ModelContext(container)

        var descriptor = FetchDescriptor<ILTask>()
        descriptor.predicate = predicate
        descriptor.sortBy = [SortDescriptor(\.effectiveFrom, order: .forward)] // TODO: support custom sorting?

        // TODO: organize this more, e.g., just return the head versions? (group by identifier?)
        return try context.fetch(descriptor)
    }
}
