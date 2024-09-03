//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SwiftData
import SwiftUI


@MainActor
public final class ILScheduler: Module, EnvironmentAccessible, Sendable {
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

    var context: ModelContext {
        get throws {
            try container.mainContext
        }
    }

    // TODO: how to specify the initial tasks
    //   -> result builder and then `getOrCreate` operation and `updateIfNotEqual`?

    public nonisolated init() {}

    public func configure() {
        let configuration: ModelConfiguration
#if targetEnvironment(simulator)
        configuration = ModelConfiguration(isStoredInMemoryOnly: true)
#else
        let storageUrl = URL.documentsDirectory.appending(path: "edu.stanford.spezi.scheduler.storage.sqlite")
        configuration = ModelConfiguration(url: storageUrl)
#endif
        do {
            _container = try ModelContainer(for: ILTask.self, configurations: configuration)
        } catch {
            logger.error("Failed to initializer scheduler model container: \(error)")
        }
    }

    // TODO: best way to configure initial tasks?
    public func addTasks(_ tasks: ILTask...) {
        self.addTasks(tasks)
    }

    public func deleteTasks(_ tasks: ILTask...) {
        self.deleteTasks(tasks)
    }


    public func addTasks(_ tasks: [ILTask]) {
        guard let context = try? context else {
            logger.error("Failed to persist tasks as container failed to be configured: \(tasks.map { $0.id }.joined(separator: ", "))")
            return
        }

        for task in tasks {
            context.insert(task)
        }
    }

    public func deleteTasks(_ tasks: [ILTask]) {
        guard let context = try? context else {
            logger.error("Failed to delete tasks as container failed to be configured: \(tasks.map { $0.id }.joined(separator: ", "))")
            return
        }

        for task in tasks {
            context.delete(task)
        }
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

    // TODO: allow to query outcomes separately?
    public func queryEvents(for range: Range<Date>) throws -> [ILEvent] { // TODO: could be async and return type is sending!
        let tasks = try queryTasks(for: range)
        let outcomes = try queryOutcomes(for: range)

        let outcomesByOccurrence = outcomes.reduce(into: [:]) { partialResult, outcome in
            partialResult[outcome.occurrenceStartDate] = outcome
        }

        return tasks
            .flatMap { task in
                // If there is a newer task version, we only calculate the events till that the current task is effective.
                // Otherwise, use the upperBound from the range.
                let upperBound: Date
                if let effectiveFrom = task.nextVersion?.effectiveFrom {
                    upperBound = min(effectiveFrom, range.upperBound) // the range might end before the next version is effective
                } else {
                    upperBound = range.upperBound
                }

                return task.schedule
                    .occurrences(in: range.lowerBound..<upperBound)
                    .map { occurrence in
                        let outcome = outcomesByOccurrence[occurrence.start]
                        return ILEvent(task: task, occurrence: occurrence, outcome: outcome)
                    }
            }
            .sorted { lhs, rhs in
                lhs.occurrence < rhs.occurrence
            }
    }

    private func queryTask(with predicate: Predicate<ILTask>) throws -> [ILTask] {
        // TODO: allow to retrieve an anchor (the list of model identifiers)

        // TODO: allow to specify custom predicates (e.g., restrict the task id?)

        var descriptor = FetchDescriptor<ILTask>()
        descriptor.predicate = predicate
        descriptor.sortBy = [SortDescriptor(\.effectiveFrom, order: .forward)] // TODO: support custom sorting?

        // TODO: configure pre-fetching \.outcomes!
        // make sure querying the next version is always efficient
        descriptor.relationshipKeyPathsForPrefetching = [\.nextVersion]

        return try context.fetch(descriptor)
    }

    private func queryOutcomes(for range: Range<Date>) throws -> [Outcome] {
        var descriptor = FetchDescriptor<Outcome>()
        descriptor.predicate = #Predicate { outcome in
            range.contains(outcome.occurrenceStartDate)
        }

        return try context.fetch(descriptor)
    }
}
