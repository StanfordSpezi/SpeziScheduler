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
public final class ILScheduler {
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

    /// Configure the Scheduler.
    public nonisolated init() {}

    init(testingContainer: ModelContainer) {
        self._container = testingContainer
    }

    /// Configure the Scheduler module.
    @_documentation(visibility: internal)
    public func configure() {
        guard _container == nil else {
            return // we have a container injected for testing purposes
        }

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
            // TODO: store the error and propagate via invalidContainer error?
            logger.error("Failed to initializer scheduler model container: \(error)")
        }
    }

    
    /// Add a new task or update its content if it exists and its properties changed.
    ///
    /// This method will check if the task with the specified `id` is already present in the model container. If not, it inserts a new instance of this task.
    /// If the task already exists in the store, this method checks if the contents of task are up to date. If not, a new version is created with the updated values.
    ///
    /// - Parameters:
    ///   - id: The identifier of the task.
    ///   - title: The user-visible task title.
    ///   - instructions: The user-visible instructions for the task.
    ///   - schedule: The schedule for the events of this task.
    ///   - effectiveFrom: The date from which this version of the task is effective. You typically do not want to modify this parameter.
    ///     If you do specify a custom value, make sure to specify it relative to `now`.
    ///   - contextClosure: The closure that allows to customize the ``ILTask/Context`` that is stored with the task.
    /// - Returns: Returns the latest version of the `task` and if the task was updated or created indicated by `didChange`.
    @discardableResult
    public func createOrUpdateTask(
        id: String,
        title: LocalizedStringResource,
        instructions: LocalizedStringResource,
        schedule: ILSchedule,
        effectiveFrom: Date = .now,
        with contextClosure: ((inout ILTask.Context) -> Void)? = nil
    ) throws -> (task: ILTask, didChange: Bool) {
        let context = try context
        let results = try context.fetch(FetchDescriptor<ILTask>(
            predicate: #Predicate { task in
                task.id == id && task.nextVersion == nil
            }
        ))

        if let existingTask = results.first {
            return existingTask.createUpdatedVersion(
                title: title,
                instructions: instructions,
                schedule: schedule,
                effectiveFrom: effectiveFrom,
                with: contextClosure
            )
        } else {
            let task = ILTask(
                id: id,
                title: title,
                instructions: instructions,
                schedule: schedule,
                effectiveFrom: effectiveFrom,
                with: contextClosure ?? { _ in }
            )
            context.insert(task)
            try context.save() // TODO: should we?
            return (task, true)
        }
    }
    
    /// Delete a task from the store.
    ///
    /// This permanently deletes a task (version) from the store.
    /// - Important: This will only delete this particular version of the Task and outcomes that are associated with this version of the task!
    ///   It will not delete previous versions of the task. Deleting a version of a task might reactive the schedule from the previous version.
    ///
    /// - Tip: If you want to stop a task from reoccurring, simply create a new version of a task with an appropriate ``ILTask/effectiveFrom`` date and make sure
    ///     that the ``ILTask/schedule`` doesn't produce any more occurrences.
    ///
    /// - Parameter tasks: The variadic list of task to delete.
    public func deleteTasks(_ tasks: ILTask...) {
        self.deleteTasks(tasks)
    }
    
    /// Delete a task from the store.
    ///
    /// This permanently deletes a task (version) from the store.
    /// - Important: This will only delete this particular version of the Task and outcomes that are associated with this version of the task!
    ///   It will not delete previous versions of the task. Deleting a version of a task might reactive the schedule from the previous version.
    ///
    /// - Tip: If you want to stop a task from reoccurring, simply create a new version of a task with an appropriate ``ILTask/effectiveFrom`` date and make sure
    ///     that the ``ILTask/schedule`` doesn't produce any more occurrences.
    ///
    /// - Parameter tasks: The list of task to delete.
    public func deleteTasks(_ tasks: [ILTask]) {
        // TODO: easy "mark deleted" method (that creates a new tombstone= task version with no events in the schedule).
        guard let context = try? context else {
            logger.error("Failed to delete tasks as container failed to be configured: \(tasks.map { $0.id }.joined(separator: ", "))")
            return
        }

        for task in tasks {
            context.delete(task)
        }
    }
    
    /// Query the list of tasks.
    ///
    /// This method queries all tasks (and task versions) for the specified parameters.
    /// Tasks are stored in an append-only format. When you modify a Task, it is added as a new version (entry) to the store with an updated ``ILTask/effectiveFrom`` date.
    /// This query method returns all task and task versions that are valid in the provided `range`. This could return multiple versions of the same task, if the date it got changed
    /// is contained in the queried `range`.
    ///
    /// - Parameters:
    ///   - range: The closed date range in which queried task versions need to be effective.
    ///   - predicate: Specify additional conditions to filter the list of task that is fetched from the store.
    ///   - sortDescriptors: Additionally sort descriptors. The list of task is always sorted by its ``ILTask/effectiveFrom``.
    ///   - prefetchOutcomes: Flag to indicate if the ``ILTask/outcomes`` relationship should be pre-fetched. By default this is `false` and relationship data is loaded lazily.
    /// - Returns: The list of `ILTask` that are effective in the specified date range and match the specified `predicate`. The result is ordered by the specified `sortDescriptors`.
    public func queryTasks(
        for range: ClosedRange<Date>,
        predicate: Predicate<ILTask> = #Predicate { _ in true },
        sortBy sortDescriptors: [SortDescriptor<ILTask>] = [],
        prefetchOutcomes: Bool = false
    ) throws -> [ILTask] {
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

        return try queryTask(with: inClosedRangePredicate, combineWith: predicate, sortBy: sortDescriptors, prefetchOutcomes: prefetchOutcomes)
    }

    
    /// Query the list of tasks.
    ///
    /// This method queries all tasks (and task versions) for the specified parameters.
    /// Tasks are stored in an append-only format. When you modify a Task, it is added as a new version (entry) to the store with an updated ``ILTask/effectiveFrom`` date.
    /// This query method returns all task and task versions that are valid in the provided `range`. This could return multiple versions of the same task, if the date it got changed
    /// is contained in the queried `range`.
    ///
    /// - Parameters:
    ///   - range: The date range in which queried task versions need to be effective.
    ///   - predicate: Specify additional conditions to filter the list of task that is fetched from the store.
    ///   - sortDescriptors: Additionally sort descriptors. The list of task is always sorted by its ``ILTask/effectiveFrom``.
    ///   - prefetchOutcomes: Flag to indicate if the ``ILTask/outcomes`` relationship should be pre-fetched. By default this is `false` and relationship data is loaded lazily.
    /// - Returns: The list of `ILTask` that are effective in the specified date range and match the specified `predicate`. The result is ordered by the specified `sortDescriptors`.
    public func queryTasks(
        for range: Range<Date>,
        predicate: Predicate<ILTask> = #Predicate { _ in true },
        sortBy sortDescriptors: [SortDescriptor<ILTask>] = [],
        prefetchOutcomes: Bool = false
    ) throws -> [ILTask] {
        let inRangePredicate = #Predicate<ILTask> { task in
            if let effectiveTo = task.nextVersion?.effectiveFrom {
                range.contains(task.effectiveFrom) // TODO: is this also wrong?
                    || (range.lowerBound <= effectiveTo && effectiveTo <= range.upperBound)
            } else {
                task.effectiveFrom < range.upperBound
            }
        }

        return try queryTask(with: inRangePredicate, combineWith: predicate, sortBy: sortDescriptors, prefetchOutcomes: prefetchOutcomes)
    }
    
    /// Query the list of events.
    ///
    /// This method fetches all tasks that are effective in the specified `range` and fulfill the additional `taskPredicate` (if specified).
    /// For these tasks, the list of outcomes are fetched (if they exist), which had their occurrence start in the provided `range`. These two list are then merged into a list of ``ILEvent``s
    /// that is sorted by its ``ILEvent/occurrence`` in ascending order.
    ///
    /// This method queries all tasks for the specified parameters, fetches their list of outcomes to produce a list of events.
    ///
    /// - Parameters:
    ///   - range: A date range that must contain the effective task versions and the start date of the event ``Occurrence``.
    ///   - taskPredicate: An additional predicate that allows to pre-filter the list of task that should be considered.
    /// - Returns: The list of events that occurred in the given date `range` for tasks that fulfill the provided `taskPredicate` returned as a list that is sorted by the events
    ///     ``ILEvent/occurrence`` in ascending order.
    public func queryEvents( // TODO: allow closed range as well?
        for range: Range<Date>,
        predicate taskPredicate: Predicate<ILTask> = #Predicate { _ in true }
    ) throws -> [ILEvent] {
        let tasks = try queryTasks(for: range, predicate: taskPredicate)
        let outcomes = try queryOutcomes(for: range, predicate: taskPredicate)

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

    private func queryTask(
        with basePredicate: Predicate<ILTask>,
        combineWith userPredicate: Predicate<ILTask>,
        sortBy sortDescriptors: [SortDescriptor<ILTask>],
        prefetchOutcomes: Bool
    ) throws -> [ILTask] {
        var descriptor = FetchDescriptor<ILTask>()
        descriptor.predicate = #Predicate { task in
            basePredicate.evaluate(task) && userPredicate.evaluate(task)
        }
        descriptor.sortBy = sortDescriptors
        descriptor.sortBy.append(SortDescriptor(\.effectiveFrom, order: .forward))

        // make sure querying the next version is always efficient
        descriptor.relationshipKeyPathsForPrefetching = [\.nextVersion]

        if prefetchOutcomes {
            descriptor.relationshipKeyPathsForPrefetching.append(\.outcomes)
        }

        return try context.fetch(descriptor)
    }

    private func queryOutcomes(for range: Range<Date>, predicate taskPredicate: Predicate<ILTask>) throws -> [Outcome] {
        var descriptor = FetchDescriptor<Outcome>()
        descriptor.predicate = #Predicate { outcome in
            range.contains(outcome.occurrenceStartDate) && taskPredicate.evaluate(outcome.task)
        }

        return try context.fetch(descriptor)
    }
}


extension ILScheduler: Module, EnvironmentAccessible, Sendable {}


extension ILScheduler {
    public enum DataError: Error {
        case invalidContainer
    }
}


extension ILScheduler.DataError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidContainer:
            String(localized: "Invalid Container")
        }
    }

    public var failureReason: String? {
        switch self {
        case .invalidContainer:
            String(localized: "The underlying storage container failed to initialize.")
        }
    }
}
