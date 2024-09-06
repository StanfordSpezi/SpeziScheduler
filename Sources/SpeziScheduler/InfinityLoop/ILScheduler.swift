//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Combine
import Foundation
import Spezi
import SwiftData
import SwiftUI

// TODO: can we formulate 5pm every Friday that "adjusts" to the timezone? some might want to have a fixed time?
//  => is auto updating current the solution?
// TODO: allow to specify "text" LocalizationValue (e.g., Breakfast, Lunch, etc), otherwise we use the time (and date?)?
// TODO: bring back support for randomly displaced events? random generated seed?
// TODO: have a simple entry macro for storage keys?
// TODO: easy "mark deleted" method (that creates a new tombstone= task version with no events in the schedule).
// TODO: UI test the following things for @EventQuery:
//  - update if there is a new version of a Task inserted (via scheduler, via task directly)
//  - update if the outcome is added to a task version


@MainActor
public final class ILScheduler {
    @Application(\.logger)
    private var logger

    private var _container: Result<ModelContainer, Error>?

    private var container: ModelContainer {
        get throws {
            guard let container = _container else {
                throw DataError.invalidContainer(nil)
            }
            return try container.get()
        }
    }

    var context: ModelContext {
        get throws {
            try container.mainContext
        }
    }


    /// A task that slightly delays saving tasks.
    private var saveTask: _Concurrency.Task<Void, Never>?

    /// Configure the Scheduler.
    public nonisolated init() {}

    
    /// Configure the Scheduler with a pre-populated model container.
    /// - Parameter testingContainer: The model container that is preconfigured with the ``ILTask`` and ``Outcome`` models.
    @_spi(TestingSupport)
    public init(testingContainer: ModelContainer) {
        self._container = .success(testingContainer)
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
            _container = .success(try ModelContainer(for: ILTask.self, Outcome.self, configurations: configuration))
        } catch {
            logger.error("Failed to initializer scheduler model container: \(error)")
            _container = .failure(error)
        }


        // This is a really good article explaining some of the concurrency considerations with SwiftData
        // https://medium.com/@samhastingsis/use-swiftdata-like-a-boss-92c05cba73bf
        // It also makes it easier to understand the SwiftData-related infrastructure around Spezi Scheduler.
        // One could think that Apple could have provided a lot of this information in their documentation.
    }


    /// Schedules a new save.
    ///
    /// When we add a new task we want to instantly save it to disk. This helps to, e.g., make sure a `@EventQuery` receives the update by subscribing to the
    /// `didSave` notification. We delay saving the context by a bit, by queuing a task for the next possible execution. This helps to avoid that adding a new task model
    /// blocks longer than needed and makes sure that creating multiple tasks in sequence (which happens at startup) doesn't call `save()` more often than required.
    private func scheduleSave(for context: ModelContext) {
        guard saveTask == nil else {
            return // se docs above
        }

        saveTask = _Concurrency.Task { [logger] in
            defer {
                saveTask = nil
            }

            do {
                try context.save()
            } catch {
                logger.error("Failed to save the scheduler model context: \(error)")
            }
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
        title: String.LocalizationValue,
        instructions: String.LocalizationValue,
        schedule: ILSchedule,
        effectiveFrom: Date = .now,
        with contextClosure: ((inout ILTask.Context) -> Void)? = nil
    ) throws -> (task: ILTask, didChange: Bool) {
        let context = try context

        let predicate: Predicate<ILTask> = #Predicate { task in
            task.id == id && task.nextVersion == nil
        }
        let results = try context.fetch(FetchDescriptor<ILTask>(predicate: predicate))

        if let existingTask = results.first {
            let descriptor = FetchDescriptor<Outcome>(
                predicate: #Predicate { outcome in
                    predicate.evaluate(outcome.task) // ensure we use the same predicate
                        && outcome.occurrenceStartDate >= effectiveFrom
                }
            )
            let outcomesThatWouldBeShadowed = try context.fetchCount(descriptor)

            if outcomesThatWouldBeShadowed > 0 {
                // an updated task cannot shadow already recorded outcomes of a previous task version
                throw ILScheduler.DataError.shadowingPreviousOutcomes
            }

            // while this is throwing, it won't really throw for us, as we do all the checks beforehand
            let result = try existingTask.createUpdatedVersion(
                skipShadowCheck: true, // we perform the check much more efficient with the query above and do not require fetching all outcomes
                title: title,
                instructions: instructions,
                schedule: schedule,
                effectiveFrom: effectiveFrom,
                with: contextClosure
            )

            if result.didChange {
                scheduleSave(for: context)
            }

            return result
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
            scheduleSave(for: context)
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

    func addOutcome(_ outcome: Outcome) {
        let context: ModelContext
        do {
            context = try self.context
        } catch {
            logger.error("Failed to persist outcome for task \(outcome.task.id): \(error)")
            return
        }

        context.insert(outcome)
        scheduleSave(for: context)
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
        try queryTask(with: inClosedRangePredicate(for: range), combineWith: predicate, sortBy: sortDescriptors, prefetchOutcomes: prefetchOutcomes)
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
        try queryTask(with: inRangePredicate(for: range), combineWith: predicate, sortBy: sortDescriptors, prefetchOutcomes: prefetchOutcomes)
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
    public func queryEvents(
        for range: Range<Date>,
        predicate taskPredicate: Predicate<ILTask> = #Predicate { _ in true }
    ) throws -> [ILEvent] {
        let tasks = try queryTasks(for: range, predicate: taskPredicate)
        let outcomes = try queryOutcomes(for: range, predicate: taskPredicate)

        let outcomesByOccurrence = outcomes.reduce(into: [:]) { partialResult, outcome in
            partialResult[outcome.occurrenceStartDate] = outcome
        }

        print("Task count: \(tasks.count), \(tasks.map { $0.id }.joined(separator: ", "))") // TODO: remove

        return tasks
            .flatMap { task in
                // If there is a newer task version, we only calculate the events till that the current task is effective.
                // Otherwise, use the upperBound from the range.
                let upperBound: Date
                // Accessing `nextVersion` is is vital for the `EventQuery`. The property will be tracked using observation.
                // Inserting (or removing) a new task version will, therefore, instantly cause a view refresh and updating the query results.
                if let effectiveFrom = task.nextVersion?.effectiveFrom {
                    upperBound = min(effectiveFrom, range.upperBound) // the range might end before the next version is effective
                } else {
                    upperBound = range.upperBound
                }

                let lowerBound: Date
                if task.previousVersion != nil {
                    // if there is a previous version, the previous version is responsible should the lowerBound be less than the
                    // date that this version of this task is effective from
                    lowerBound = max(task.effectiveFrom, range.lowerBound)
                } else {
                    lowerBound = range.lowerBound
                }

                return task.schedule
                    .occurrences(in: lowerBound..<upperBound)
                    .map { occurrence in
                        if let outcome = outcomesByOccurrence[occurrence.start] {
                            ILEvent(task: task, occurrence: occurrence, outcome: .value(outcome))
                        } else {
                            ILEvent(task: task, occurrence: occurrence, outcome: .createWith(self))
                        }
                    }
            }
            .sorted { lhs, rhs in
                lhs.occurrence < rhs.occurrence
            }
    }

    func queryEventsAnchor(
        for range: Range<Date>,
        predicate taskPredicate: Predicate<ILTask> = #Predicate { _ in true }
    ) throws -> Set<PersistentIdentifier> {
        let taskIdentifier = try queryTaskIdentifiers(with: inRangePredicate(for: range), combineWith: taskPredicate)
        let outcomeIdentifiers = try queryOutcomeIdentifiers(for: range, predicate: taskPredicate)

        return taskIdentifier.union(outcomeIdentifiers)
    }

    func sinkDidSavePublisher(into consume: @escaping (Notification) -> Void) throws -> AnyCancellable {
        let context = try context

        return NotificationCenter.default.publisher(for: ModelContext.didSave, object: context)
            .sink { notification in
                // We use the mainContext. Therefore, the vent will always be called from the main actor
                MainActor.assumeIsolated {
                    consume(notification)
                }
            }
    }
}


extension ILScheduler: Module, EnvironmentAccessible, Sendable {}

// MARK: - Fetch Implementations

extension ILScheduler {
    private func queryTask(
        with basePredicate: Predicate<ILTask>,
        combineWith userPredicate: Predicate<ILTask>,
        sortBy sortDescriptors: [SortDescriptor<ILTask>],
        prefetchOutcomes: Bool
    ) throws -> [ILTask] {
        var descriptor = FetchDescriptor<ILTask>(
            predicate: #Predicate { task in
                basePredicate.evaluate(task) && userPredicate.evaluate(task)
            },
            sortBy: sortDescriptors
        )
        descriptor.sortBy.append(SortDescriptor(\.effectiveFrom, order: .forward))

        // make sure querying the next version is always efficient
        descriptor.relationshipKeyPathsForPrefetching = [\.nextVersion]

        if prefetchOutcomes {
            descriptor.relationshipKeyPathsForPrefetching.append(\.outcomes)
        }

        return try context.fetch(descriptor)
    }

    private func queryOutcomes(for range: Range<Date>, predicate taskPredicate: Predicate<ILTask>) throws -> [Outcome] {
        let descriptor = FetchDescriptor<Outcome>(
            predicate: #Predicate { outcome in
                range.contains(outcome.occurrenceStartDate) && taskPredicate.evaluate(outcome.task)
            }
        )

        return try context.fetch(descriptor)
    }

    private func queryTaskIdentifiers(
        with basePredicate: Predicate<ILTask>,
        combineWith userPredicate: Predicate<ILTask>
    ) throws -> Set<PersistentIdentifier> {
        let descriptor = FetchDescriptor<ILTask>(
            predicate: #Predicate { task in
                basePredicate.evaluate(task) && userPredicate.evaluate(task)
            }
        )

        return try Set(context.fetchIdentifiers(descriptor))
    }

    private func queryOutcomeIdentifiers(for range: Range<Date>, predicate taskPredicate: Predicate<ILTask>) throws -> Set<PersistentIdentifier> {
        let descriptor = FetchDescriptor<Outcome>(
            predicate: #Predicate { outcome in
                range.contains(outcome.occurrenceStartDate) && taskPredicate.evaluate(outcome.task)
            }
        )

        return try Set(context.fetchIdentifiers(descriptor))
    }
}

// MARK: - Predicate Creation

extension ILScheduler {
    private func inRangePredicate(for range: Range<Date>) -> Predicate<ILTask> {
        #Predicate<ILTask> { task in
            if let effectiveTo = task.nextVersion?.effectiveFrom {
                // This basically boils down to
                // let taskRange = task.effectiveFrom...<effectiveTo
                // return taskRange.overlaps(range)

                task.effectiveFrom < range.upperBound
                    && range.lowerBound < effectiveTo
            } else {
                // task lifetime is effectively an `PartialRangeFrom`. So all we do is to check if the `range` overlaps with the lower bound
                task.effectiveFrom < range.upperBound
            }
        }
    }

    private func inClosedRangePredicate(for range: ClosedRange<Date>) -> Predicate<ILTask> {
        // see comments above for an explanation
        #Predicate<ILTask> { task in
            if let effectiveTo = task.nextVersion?.effectiveFrom {

                task.effectiveFrom <= range.upperBound
                    && range.lowerBound < effectiveTo
            } else {
                // task lifetime is effectively an `PartialRangeFrom`. So all we do is to check if the closed `range` overlaps with the lower bound
                task.effectiveFrom <= range.upperBound
            }
        }
    }
}


// MARK: - Error

extension ILScheduler {
    public enum DataError: Error {
        /// No model container present.
        ///
        /// The container failed to initialize at startup. The `underlying` error is the error occurred when trying to initialize the container.
        /// The `underlying` is `nil` if the container was accessed before ``ILScheduler/configure()`` was called.
        case invalidContainer(_ underlying: (any Error)?)
        /// An updated Task cannot shadow the outcomes of a previous task version.
        ///
        /// Make sure the ``ILTask/effectiveFrom`` date is larger than the start that of the latest completed event.
        case shadowingPreviousOutcomes
        /// Trying to modify a task that is already super-seeded by a newer version.
        ///
        /// This error is thrown if you are trying to modify a task version that is already outdated. Make sure to always apply updates to the newest version of a task.
        case nextVersionAlreadyPresent
    }
}


extension ILScheduler.DataError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidContainer:
            String(localized: "Invalid Container")
        case .shadowingPreviousOutcomes:
            String(localized: "Shadowing previous Outcomes")
        case .nextVersionAlreadyPresent:
            String(localized: "Outdated Task")
        }
    }

    public var failureReason: String? {
        switch self {
        case .invalidContainer:
            String(localized: "The underlying storage container failed to initialize.")
        case .shadowingPreviousOutcomes:
            String(localized: "An updated Task cannot shadow the outcomes of a previous task version.")
        case .nextVersionAlreadyPresent:
            String(localized: "Only the latest version of a task can be changed.")
        }
    }
}


// swiftlint:disable:this file_length
