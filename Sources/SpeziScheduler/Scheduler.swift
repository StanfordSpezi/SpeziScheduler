//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Combine
import Foundation
import RuntimeAssertions
import Spezi
import SpeziFoundation
import SwiftData
import SwiftUI


/// Schedule and query tasks and their events.
///
/// A ``Task`` is an potentially repeated action or work that a user is supposed to perform. An ``Event`` represents a single
/// occurrence of a task, that is derived from its ``Schedule``.
///
/// You use the `Scheduler` module to manage the persistence store of your tasks. It provides a versioned, append-only store
/// for tasks. It allows to modify the properties (e.g., schedule) of future events without affecting occurrences of the past.
///
/// You create and automatically update your tasks
/// using ``createOrUpdateTask(id:title:instructions:category:schedule:completionPolicy:scheduleNotifications:notificationThread:tags:effectiveFrom:shadowedOutcomesHandling:with:)``.
///
/// Below is a example on how to create your own [`Module`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module)
/// to manage your tasks and ensure they are always up to date.
///
/// ```swift
/// import Spezi
/// import SpeziScheduler
///
/// class MySchedulerModule: Module {
///     @Dependency(Scheduler.self)
///     private var scheduler
///
///     init() {}
///
///     func configure() {
///         do {
///             try scheduler.createOrUpdateTask(
///                 id: "my-daily-task",
///                 title: "Daily Questionnaire",
///             	instructions: "Please fill out the Questionnaire every day.",
///                 category: Task.Category("Questionnaire", systemName: "list.clipboard.fill"),
///                 schedule: .daily(hour: 9, minute: 0, startingAt: .today)
///             )
///         } catch {
///             // handle error (e.g., visualize in your UI)
///         }
///     }
/// }
/// ```
///
/// - Note: When using the `Scheduler` in a macOS application, your app needs to be sandboxed if you want to use the ``PersistenceConfiguration/onDisk`` persistance option.
///
/// ## Topics
///
/// ### Configuration
/// - ``init()``
///
/// ### Creating and Updating Tasks
/// - ``createOrUpdateTask(id:title:instructions:category:schedule:completionPolicy:scheduleNotifications:notificationThread:tags:effectiveFrom:shadowedOutcomesHandling:with:)``
///
/// ### Query Tasks
/// - ``queryTasks(for:predicate:sortBy:fetchLimit:prefetchOutcomes:)-8z86i``
/// - ``queryTasks(for:predicate:sortBy:fetchLimit:prefetchOutcomes:)-5cuwe``
///
/// ### Query Events
/// - ``queryEvents(for:predicate:)``
///
/// ### Permanently delete a Task version
/// - ``deleteTasks(_:)-9jjbl``
/// - ``deleteTasks(_:)-8h2bj``
///
/// ### Permanently delete all Task versions
/// - ``deleteAllVersions(of:)``
/// - ``deleteAllVersions(ofTask:)``
@MainActor
public final class Scheduler: Module, EnvironmentAccessible, DefaultInitializable, Sendable {
    /// How shadowed outcomes detected when updating a ``Task`` should be handled.
    public enum TaskUpdateShadowedOutcomesHandling {
        /// Attempting to update an already-existing task in a way that would shadow existing outcomes will result in an error
        case throwError
        /// Attempting to update an already-existing task in a way that would shadow existing outcomes will result in the shadowed outcomes being deleted.
        case delete
    }
    
    /// How the ``Scheduler`` should persist its data.
    public enum PersistenceConfiguration {
        /// The ``Scheduler`` will use an on-disk database for persistence.
        case onDisk
        /// The ``Scheduler`` will use an in-memory database for persistence.
        /// Intended for testing purposes.
        case inMemory
        /// The ``Scheduler`` will use the specified `ModelContainer` for persistence.
        ///
        /// - Note: This is intended for configuring the ``Scheduler`` with a pre-populated model container that is already configured for the ``Task`` and ``Outcome`` types.
        @_spi(TestingSupport)
        case testingContainer(ModelContainer)
    }
    
    /// Utility type that allows us to easily defer a `context.save()` operation until the next run loop operation.
    /// This is benefitial since it means that we'll be able to skip unnecessary `save()`s if multiple changes are made to the context directly after each other.
    @MainActor
    private final class SaveTask {
        private typealias Task = _Concurrency.Task
        
        private unowned let scheduler: Scheduler
        private var saveTask: Task<Void, Never>?
        private var scheduleNotifications = false
        
        init(scheduler: Scheduler, context: ModelContext) {
            self.scheduler = scheduler
            saveTask = Task { @MainActor in
                // make sure that we don't get inlined into the current run loop iteration
                await Task.yield()
                defer {
                    self.saveTask = nil
                    scheduler.saveTask = nil
                }
                do {
                    try context.save()
                } catch {
                    scheduler.logger.error("Failed to save the scheduler model context: \(error)")
                }
                if scheduleNotifications {
                    scheduler.notifications.scheduleNotificationsUpdate(using: scheduler)
                }
            }
        }
        
        func rescheduleNotifications() {
            scheduleNotifications = true
        }
    }
    
    /// We disable that for now. We might need to restore some information to cancel notifications.
    private static let purgeLegacyStorage = false
    
    @Application(\.logger)
    private var logger
    
    @Dependency(SchedulerNotifications.self)
    private var notifications
    
    private let _container: Result<ModelContainer, any Error>
    
    private var container: ModelContainer {
        get throws {
            do {
                return try _container.get()
            } catch {
                throw DataError.invalidContainer(error)
            }
        }
    }
    
    var context: ModelContext {
        get throws {
            try container.mainContext
        }
    }
    
    
    /// A task that slightly delays saving tasks.
    private var saveTask: SaveTask?
    /// Observer closures that are called in response to new ``Outcome``s being added to the Scheduler.
    /// - Note: the `UUID` only serves as a means of identifying the individual closures, so that we can remove them upon termination
    private var outcomeObservers: [UUID: @MainActor (Outcome) -> Void] = [:]
    /// Creates a new Scheduler, using on-disk persistence.
    public nonisolated convenience init() {
        self.init(persistence: .onDisk)
    }
    
    /// Creates a new Scheduler, using the specified persistence configuration.
    public nonisolated init(persistence: PersistenceConfiguration) {
        switch persistence {
        case .onDisk:
            guard ProcessInfo.isRunningInSandbox else {
                preconditionFailure(
                    """
                    The current application is running in a non-sandboxed environment.
                    In this case, the `onDisk` persistence configuration is not available,
                    since the \(Scheduler.self) module would end up placing its database directly into
                    the current user's Documents directory (i.e., `~/Documents`).
                    Specify another persistence option, or enable sandboxing for the application.
                    """
                )
            }
            _container = Result {
                try ModelContainer(
                    for: Task.self, Outcome.self, // swiftlint:disable:this multiline_arguments
                    configurations: ModelConfiguration(url: URL.documentsDirectory.appending(path: "edu.stanford.spezi.scheduler.storage.sqlite"))
                )
            }
        case .inMemory:
            _container = Result {
                try ModelContainer(
                    for: Task.self, Outcome.self, // swiftlint:disable:this multiline_arguments
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
            }
        case .testingContainer(let modelContainer):
            self._container = .success(modelContainer)
        }
    }
    
    
    /// Configure the Scheduler module.
    @_documentation(visibility: internal)
    public func configure() {
        switch _container {
        case .failure(let error):
            logger.error("Failed to initialize ModelContainer for Scheduler module: \(error)")
        case .success:
            break
        }
        // This is a really good article explaining some of the concurrency considerations with SwiftData
        // https://medium.com/@samhastingsis/use-swiftdata-like-a-boss-92c05cba73bf
        // It also makes it easier to understand the SwiftData-related infrastructure around Spezi Scheduler.
        // One could think that Apple could have provided a lot of this information in their documentation.
        notifications.registerProcessingTask(using: self)
    }
    
    /// Trigger a manual refresh of the scheduled notifications.
    ///
    /// Call this method after requesting notification authorization from the user, if you disabled the ``SchedulerNotifications/automaticallyRequestProvisionalAuthorization``
    /// option.
    public func manuallyScheduleNotificationRefresh() {
        notifications.scheduleNotificationsUpdate(using: self)
    }
    
    
    /// Schedules a new save.
    ///
    /// When we add a new task we want to instantly save it to disk. This helps to, e.g., make sure a `@EventQuery` receives the update by subscribing to the
    /// `didSave` notification. We delay saving the context by a bit, by queuing a task for the next possible execution. This helps to avoid that adding a new task model
    /// blocks longer than needed and makes sure that creating multiple tasks in sequence (which happens at startup) doesn't call `save()` more often than required.
    ///
    /// - parameter context: The `ModelContext` for which a save should be scheduled
    /// - parameter forceSave: Flag to always schedule an immediate save, regardless of whether `context.hasChanges` is actually true. Required to work around FB17583572.
    /// - parameter rescheduleNotifications: whether the scheduler should reschedule notifications for all ``Task``s.
    private func scheduleSave(for context: ModelContext, forceSave: Bool = false, rescheduleNotifications: Bool) {
        // swiftlint:disable:previous function_default_parameter_at_end
        if saveTask != nil {
            // as we run on the MainActor in the task, if the saveTask is not nil,
            // we know that the Task isn't executed yet but will on the "next" tick.
        } else if forceSave || context.hasChanges {
            saveTask = SaveTask(scheduler: self, context: context)
        }
        // we now have a SaveTask scheduled, so all we need to do is to update the notification scheduling if necessary
        if rescheduleNotifications {
            saveTask?.rescheduleNotifications() // will never be nil
        }
    }
    
    
    /// Add a new task or update its content if it exists and its properties changed.
    ///
    /// This method will check if the task with the specified `id` is already present in the model container. If not, it inserts a new instance of this task.
    /// If the task already exists in the store, this method checks if the contents of task are up to date. If not, a new version is created with the updated values.
    ///
    /// - Warning: `title` and `instructions` are localizable strings. If you change any of these properties, make sure to maintain the previous
    ///     keys in your String catalog to make sure that previous versions maintain to get displayed for existing users of your application.
    ///
    /// - Parameters:
    ///   - id: The identifier of the task.
    ///   - title: The user-visible task title.
    ///   - instructions: The user-visible instructions for the task.
    ///   - category: The user-visible category information of a task.
    ///   - schedule: The schedule for the events of this task.
    ///   - completionPolicy: The policy to decide when an event can be completed by the user.
    ///   - scheduleNotifications: Automatically schedule notifications for upcoming events.
    ///   - notificationThread: The behavior how task notifications are grouped in the notification center.
    ///   - tags: Custom tags associated with the task.
    ///   - effectiveFrom: The date from which this version of the task is effective. You typically do not want to modify this parameter.
    ///     If you do specify a custom value, make sure to specify it relative to `now`.
    ///   - shadowedOutcomesHandling: How the scheduler should deal with shadowed outcomes when updating a task.
    ///     You need to specify this parameter if you want to be able to proactively complete upcoming events.
    ///     In this case, the call to `createOrUpdateTask` might
    ///   - contextClosure: The closure that allows to customize the ``Task/Context`` that is stored with the task.
    /// - Returns: Returns the latest version of the `task` and if the task was updated or created indicated by `didChange`.
    @discardableResult
    public func createOrUpdateTask( // swiftlint:disable:this function_body_length
        id: String,
        title: String.LocalizationValue,
        instructions: String.LocalizationValue,
        category: Task.Category? = nil, // swiftlint:disable:this function_default_parameter_at_end
        schedule: Schedule,
        completionPolicy: AllowedCompletionPolicy = .sameDay,
        scheduleNotifications: Bool = false,
        notificationThread: NotificationThread = .global,
        tags: [String]? = nil, // swiftlint:disable:this discouraged_optional_collection
        effectiveFrom: Date = .now,
        shadowedOutcomesHandling: TaskUpdateShadowedOutcomesHandling = .throwError,
        with contextClosure: ((inout Task.Context) -> Void)? = nil
    ) throws -> (task: Task, didChange: Bool) {
        let context = try context
        let taskPredicate: Predicate<Task> = #Predicate { task in
            task.id == id && task.nextVersion == nil
        }
        let results = try context.fetch(FetchDescriptor<Task>(predicate: taskPredicate))
        if let existingTask = results.first {
            let outcomesThatWouldBeShadowed = try context.fetch(FetchDescriptor<Outcome>(
                predicate: #Predicate { outcome in
                    taskPredicate.evaluate(outcome.task) && outcome.occurrenceStartDate >= effectiveFrom
                }
            ))
            guard existingTask.wouldNecessitateNewTaskVersion(
                title: title,
                instructions: instructions,
                category: category,
                schedule: schedule,
                completionPolicy: completionPolicy,
                scheduleNotifications: scheduleNotifications,
                notificationThread: notificationThread,
                tags: tags,
                effectiveFrom: effectiveFrom,
                with: contextClosure
            ) else {
                return (existingTask, false)
            }
            switch shadowedOutcomesHandling {
            case .throwError:
                guard outcomesThatWouldBeShadowed.isEmpty else {
                    throw Scheduler.DataError.shadowingPreviousOutcomes
                }
            case .delete:
                for outcome in consume outcomesThatWouldBeShadowed {
                    context.delete(outcome)
                }
            }
            // while this is throwing, it won't really throw for us, as we do all the checks beforehand
            let result = try existingTask.createUpdatedVersion(
                skipShadowCheck: true, // we either have already performed the check and found no problematic outcomes, or we've deleted them all
                title: title,
                instructions: instructions,
                category: category,
                schedule: schedule,
                completionPolicy: completionPolicy,
                scheduleNotifications: scheduleNotifications,
                notificationThread: notificationThread,
                tags: tags,
                effectiveFrom: effectiveFrom,
                with: contextClosure
            )
            if result.didChange {
                let notifications = Task.requiresNotificationRescheduling(previous: existingTask, updated: result.task)
                scheduleSave(for: context, rescheduleNotifications: notifications)
            }
            return result
        } else {
            // no matching existing task exists. we create a new one.
            let task = Task(
                id: id,
                title: title,
                instructions: instructions,
                category: category,
                schedule: schedule,
                completionPolicy: completionPolicy,
                scheduleNotifications: scheduleNotifications,
                notificationThread: notificationThread,
                tags: tags ?? [],
                effectiveFrom: effectiveFrom,
                with: contextClosure ?? { _ in }
            )
            context.insert(task)
            scheduleSave(for: context, rescheduleNotifications: scheduleNotifications)
            return (task, true)
        }
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
        scheduleSave(
            for: context,
            rescheduleNotifications: outcome.task.scheduleNotifications && outcome.occurrenceStartDate > .now
        )
        for (_, handler) in outcomeObservers {
            handler(outcome)
        }
    }
}


extension Scheduler {
    /// Delete a task from the store.
    ///
    /// This permanently deletes a task (version) from the store.
    /// - Important: This will delete this particular version of the Task, all future versions and outcomes that are associated with these versions of the task!
    ///   It will not delete previous versions of the task. Deleting a version of a task might reactive the schedule from the previous version.
    ///
    /// - Tip: If you want to stop a task from reoccurring, simply create a new version of a task with an appropriate ``Task/effectiveFrom`` date and make sure
    ///     that the ``Task/schedule`` doesn't produce any more occurrences.
    ///
    /// - Parameter tasks: The variadic list of task to delete.
    public func deleteTasks(_ tasks: Task...) throws {
        try self.deleteTasks(tasks)
    }
    
    /// Delete a task from the store.
    ///
    /// This permanently deletes a task (version) from the store.
    /// - Important: This will delete this particular version of the Task, all future versions and outcomes that are associated with these versions of the task!
    ///   It will not delete previous versions of the task. Deleting a version of a task might reactive the schedule from the previous version.
    ///
    /// - Tip: If you want to stop a task from reoccurring, simply create a new version of a task with an appropriate ``Task/effectiveFrom`` date and make sure
    ///     that the ``Task/schedule`` doesn't produce any more occurrences.
    ///
    /// - Parameter tasks: The list of task to delete.
    public func deleteTasks(_ tasks: consuming some Collection<Task>) throws {
        guard !tasks.isEmpty else {
            return
        }
        // What's going on here?
        //
        // It seems to be the case that SwiftData's "cascading delete" doesn't work as advertised, in that attempting to delete a Task
        // will fail (via a fatalError somewhere in SwiftData), if at least one Outcome exists for the Task.
        // (See also FB18455306.)
        // The specific issue is the fact that our `Outcome.task` backlink is a non-optional `var task: Task`, which seems to trip SwiftData up.
        // One would think that this should be fine: every Outcome is associated with exactly one Task, and the `Task.outcomes` property defines
        // a cascading-delete rule, meaning that deleting a Task should also cause the deletion of all Outcomes associated with it.
        // However, this does is not what actually happens, and instead SwiftData will crash when attempting to delete a Task for which at least
        // one Outcome exists, complaining that "Cannot remove Task from relationship task on Outcome because an appropriate default value is not configured".
        // Which, needless to say, should not constitute a fatal error, since the cascading-delete relationship between a Task and its Outcomes
        // stipulates that deleting the Task should also delete the Outcomes.
        //
        // In order to work around all of this, this function essentially re-implementes the cascading delete logic for deleting Tasks,
        // ensuring that when deleting one or more Tasks, we delete the Tasks and their Outcomes in the correct order.
        //
        // The way we do this is that we have a preprocessing step transforming the `tasks` collection passed to the function:
        // We determine, the effective "oldest" version of every Task we're asked to delete. I.e., if `tasks` contains
        // multiple versions of the same logical task, we run a small subsumption check to determine which version would end up
        // also deleting which other version (as part of the cascading delete that exists between a `Task` and its `nextVersion`).
        //
        // When performing the actual deletion, we proceed as follows:
        // 1. We delete all Outcomes associated with each to-be-deleted Task version.
        //     This needs to happen first, before we delete any Tasks, in order to ensure that there are no Outcomes for which
        //     SwiftData might run into the missing appropriate default value issue.
        //     When deleting the Outcomes, we iterate over each Task's version history, starting at the oldest version we're asked to delete
        //     (the result of the subsumption test) and going forward all the way to the newest version.
        // 2. We then (after deleting all Outcomes associated with Task versions we're asked to delete) need to perform
        //     a save operation on the context. I'm not entirely sure why this is the case, but presumably in order for the cascading
        //     delete logic in SwiftData not to see the Outcomes still existing in the storage.
        //     (The bug there, i'd assume, being that SwiftData's cascading delete operation, when deleting a model referenced via an
        //     inverse relationship, doesn't skip the deletion of that model if it's already been deleted as part of the current transaction.)
        //     Needing the explicit `save()` here is unfortunate since it might have performance implications, but it's sadly unavoidable for now.
        // 3. We then can delete the actual Tasks we're asked to delete. In this step, we can simply delete the oldest to-be-deleted
        //     version of each task, without having to take care of the cascading delete ourselves.
        //     (The reason probably being that `Task.previousVersion` and `Task.nextVersion` are both optional?)
        let oldestTaskVersionsToDelete: [Task]
        let needsNotificationsUpdate: Bool
        do {
            /// Determines if a ``Task`` is subsumed by another ``Task``,
            /// i.e. whether, for the purposes of task deletion, we should ignore the first task because we know that deleting the second one will also implicitly delete the first.
            func isTask(_ potentialNewerVersion: Task, subsumedBy potentialOlderVersion: Task) -> Bool {
                guard potentialNewerVersion.id == potentialOlderVersion.id else {
                    return false
                }
                let allVersions = potentialNewerVersion.allVersions
                guard let lhsIdx = allVersions.firstOffset(of: potentialNewerVersion),
                      let rhsIdx = allVersions.firstOffset(of: potentialOlderVersion) else {
                    return false
                }
                return rhsIdx < lhsIdx
            }
            /// The oldest version of every ``Task`` that should be deleted.
            oldestTaskVersionsToDelete = Array((consume tasks).reduce(into: Set<Task>()) { tasks, task in
                guard !tasks.contains(task) else {
                    return
                }
                if let otherIdx = tasks.firstIndex(where: { $0.id == task.id }) {
                    let other = tasks[otherIdx]
                    if isTask(task, subsumedBy: other) {
                        // nothing to do. `other` subsumes `task
                    } else if isTask(other, subsumedBy: task) {
                        // `task` subsumes `other`.
                        // -> swap them out
                        tasks.remove(other)
                        tasks.insert(task)
                    }
                } else {
                    tasks.insert(task)
                }
            })
            needsNotificationsUpdate = oldestTaskVersionsToDelete.contains { task in
                // If any of the tasks we're about to delete had notification scheduling, or if any of the tasks'
                // previous versions (which, after the delete, will become the new current versions) had notification
                // scheduling enabled, we need to perform an overall notification reschedule operation.
                task.scheduleNotifications || task.previousVersion?.scheduleNotifications == true
            }
        }
        let context = try context
        // We first need to manually delete all Outcomes belonging to the tasks we're about to delete.
        // FB18455306 ([SwiftData] deleting model crashes bc of missing default value, despite cascading delete rule.)
        for outcome in oldestTaskVersionsToDelete.flatMap({ sequence(first: $0, next: \.nextVersion).flatMap(\.outcomes) }) {
            context.delete(outcome)
        }
        try context.save()
        // Having deleted all referenced outcomes, and having saved the context, we can now delete the Tasks.
        // Note that the cascading delete here works fine (presumably because the `Task.previousVersion` and `Task.nextVersion` properties are optional?),
        // and we simply can delete the oldest version of each to-be-deleted Task.
        for task in oldestTaskVersionsToDelete {
            context.delete(task)
        }
        scheduleSave(for: context, rescheduleNotifications: needsNotificationsUpdate)
    }
    
    /// Delete all versions of the supplied task from the store.
    ///
    /// This permanently deletes all versions of a task from the store.
    ///
    /// - Important: This will also delete all outcomes associated with the task!
    ///
    /// - Tip: If you want to stop a task from reoccurring, simply create a new version of a task with an appropriate ``Task/effectiveFrom`` date and make sure
    ///     that the ``Task/schedule`` doesn't produce any more occurrences.
    ///
    /// - Parameter task: The task and all versions of it to delete.
    public func deleteAllVersions(of task: Task) throws {
        try deleteAllVersions(ofTask: task.id)
    }
    
    /// Delete all versions of the supplied task from the store.
    ///
    /// This permanently deletes all versions of a task from the store.
    ///
    /// - Important: This will also delete all outcomes associated with the task!
    ///
    /// - Tip: If you want to stop a task from reoccurring, simply create a new version of a task with an appropriate ``Task/effectiveFrom`` date and make sure
    ///     that the ``Task/schedule`` doesn't produce any more occurrences.
    ///
    /// - Parameter taskId: The task id for which you want to delete all versions. Refer to ``Task/id``.
    public func deleteAllVersions(ofTask taskId: String) throws {
        let context = try context
        // we need to perform a save operation beforehand, to make sure that the `ModelContext.delete(model:where:)` call below works properly.
        // (see also FB18429335 and FB17583572)
        try context.save()
        try context.delete(model: Task.self, where: #Predicate { $0.id == taskId })
        scheduleSave(for: context, forceSave: true, rescheduleNotifications: true)
    }
}


extension Scheduler {
    /// Query the list of tasks.
    ///
    /// This method queries all tasks (and task versions) for the specified parameters.
    /// Tasks are stored in an append-only format. When you modify a Task, it is added as a new version (entry) to the store with an updated ``Task/effectiveFrom`` date.
    /// This query method returns all task and task versions that are valid in the provided `range`. This could return multiple versions of the same task, if the date it got changed
    /// is contained in the queried `range`.
    ///
    /// - Parameters:
    ///   - range: The closed date range in which queried task versions need to be effective.
    ///   - predicate: Specify additional conditions to filter the list of task that is fetched from the store.
    ///   - sortDescriptors: Additionally sort descriptors. The list of task is always sorted by its ``Task/effectiveFrom``.
    ///   - fetchLimit: The maximum number of models the query can return.
    ///   - prefetchOutcomes: Flag to indicate if the ``Task/outcomes`` relationship should be pre-fetched. By default this is `false` and relationship data is loaded lazily.
    /// - Returns: The list of `Task` that are effective in the specified date range and match the specified `predicate`. The result is ordered by the specified `sortDescriptors`.
    public func queryTasks(
        for range: ClosedRange<Date>,
        predicate: Predicate<Task> = #Predicate { _ in true },
        sortBy sortDescriptors: [SortDescriptor<Task>] = [],
        fetchLimit: Int? = nil,
        prefetchOutcomes: Bool = false
    ) throws -> [Task] {
        try queryTasks(
            with: inClosedRangePredicate(for: range),
            combineWith: predicate,
            sortBy: sortDescriptors,
            fetchLimit: fetchLimit,
            prefetchOutcomes: prefetchOutcomes
        )
    }

    
    /// Query the list of tasks.
    ///
    /// This method queries all tasks (and task versions) for the specified parameters.
    /// Tasks are stored in an append-only format. When you modify a Task, it is added as a new version (entry) to the store with an updated ``Task/effectiveFrom`` date.
    /// This query method returns all task and task versions that are valid in the provided `range`. This could return multiple versions of the same task, if the date it got changed
    /// is contained in the queried `range`.
    ///
    /// - Parameters:
    ///   - range: The date range in which queried task versions need to be effective.
    ///   - predicate: Specify additional conditions to filter the list of task that is fetched from the store.
    ///   - sortDescriptors: Additionally sort descriptors. The list of task is always sorted by its ``Task/effectiveFrom``.
    ///   - fetchLimit: The maximum number of models the query can return.
    ///   - prefetchOutcomes: Flag to indicate if the ``Task/outcomes`` relationship should be pre-fetched. By default this is `false` and relationship data is loaded lazily.
    /// - Returns: The list of `Task` that are effective in the specified date range and match the specified `predicate`. The result is ordered by the specified `sortDescriptors`.
    public func queryTasks(
        for range: Range<Date>,
        predicate: Predicate<Task> = #Predicate { _ in true },
        sortBy sortDescriptors: [SortDescriptor<Task>] = [],
        fetchLimit: Int? = nil,
        prefetchOutcomes: Bool = false
    ) throws -> [Task] {
        try queryTasks(
            with: inRangePredicate(for: range),
            combineWith: predicate,
            sortBy: sortDescriptors,
            fetchLimit: fetchLimit,
            prefetchOutcomes: prefetchOutcomes
        )
    }

    func queryTasks(
        for range: PartialRangeFrom<Date>,
        predicate: Predicate<Task> = #Predicate { _ in true },
        sortBy sortDescriptors: [SortDescriptor<Task>] = [],
        fetchLimit: Int? = nil,
        prefetchOutcomes: Bool = false
    ) throws -> [Task] {
        try queryTasks(
            with: inPartialRangeFromPredicate(for: range),
            combineWith: predicate,
            sortBy: sortDescriptors,
            fetchLimit: fetchLimit,
            prefetchOutcomes: prefetchOutcomes
        )
    }

    /// Query the list of events.
    ///
    /// This method fetches all tasks that are effective in the specified `range` and fulfill the additional `taskPredicate` (if specified).
    /// For these tasks, the list of outcomes are fetched (if they exist), which had their occurrence start in the provided `range`. These two list are then merged into a list of ``Event``s
    /// that is sorted by its ``Event/occurrence`` in ascending order.
    ///
    /// This method queries all tasks for the specified parameters, fetches their list of outcomes to produce a list of events.
    ///
    /// - Parameters:
    ///   - range: A date range that must contain the effective task versions and the start date of the event ``Occurrence``.
    ///   - taskPredicate: An additional predicate that allows to pre-filter the list of task that should be considered.
    /// - Returns: The list of events that occurred in the given date `range` for tasks that fulfill the provided `taskPredicate` returned as a list that is sorted by the events
    ///     ``Event/occurrence`` in ascending order.
    public func queryEvents(
        for range: Range<Date>,
        predicate taskPredicate: Predicate<Task> = #Predicate { _ in true }
    ) throws -> [Event] {
        let tasks = try queryTasks(for: range, predicate: taskPredicate)
        let outcomes = try queryOutcomes(for: range, predicate: taskPredicate)
        return assembleEvents(for: range, tasks: tasks, outcomes: outcomes)
    }
    
    
    /// Query all events for a specific task, in a specific time period.
    ///
    /// - Note: This will query for events belonging to the latest version of the task.
    public func queryEvents(forTaskWithId taskId: String, in range: Range<Date>) throws -> [Event] {
        let context = try context
        guard let task = try context.fetch(FetchDescriptor<Task>(predicate: #Predicate { task in
            task.id == taskId && task.nextVersion == nil
        })).first else {
            return []
        }
        return try queryEvents(for: task, in: range)
    }
    
    /// Query all upcoming events for a specific task, in a specific time period.
    public func queryEvents(for task: Task, in range: Range<Date>) throws -> [Event] {
        let taskId = task.id
        let outcomes = try queryOutcomes(for: range, predicate: #Predicate { $0.id == taskId })
        return assembleEvents(for: range, tasks: CollectionOfOne(task), outcomes: outcomes)
    }
    
    
    // MARK: TestingSupport functions
    
    /// Fetches all ``Task``s stored in the module.
    ///
    /// - Note: This will return all versions of each ``Task`` known to the Scheduler, not just the latest one!
    @_spi(TestingSupport)
    public func queryAllTasks() throws -> [Task] {
        try self.context.fetch(FetchDescriptor<Task>())
    }
    
    /// Fetches all ``Outcome``s stored in the module.
    @_spi(TestingSupport)
    public func queryAllOutcomes() throws -> [Outcome] {
        try self.context.fetch(FetchDescriptor<Outcome>())
    }
    
    /// Deletes all tasks and associated data (e.g. outcomes) from the store.
    ///
    /// - Note: This function is intended for internal usage, to completely wipe the scheduler module to ensure a clean slate when running unit tests.
    @_spi(TestingSupport)
    public func deleteAllTasks() throws {
        try deleteTasks(try queryAllTasks())
    }
    
    /// Deletes all data from the ``Scheduler`` module's underlying data store.
    ///
    /// - Note: This function is intended for internal usage, to completely wipe the scheduler module to ensure a clean slate when running unit tests.
    @_spi(TestingSupport)
    public func eraseDatabase() throws {
        let context = try context
        try context.delete(model: Task.self)
        try context.delete(model: Outcome.self)
        try context.save()
    }
}


extension Scheduler {
    private struct OccurrenceId: Hashable {
        let taskId: Task.ID
        let startDate: Date
        
        init(task: Task, startDate: Date) {
            self.taskId = task.id
            self.startDate = startDate
        }
    }
    
    func assembleEvents(
        for range: Range<Date>,
        tasks: some Sequence<Task>,
        outcomes: [Outcome]? // swiftlint:disable:this discouraged_optional_collection
    ) -> [Event] {
        let outcomesByOccurrence = outcomes?.reduce(into: [:]) { partialResult, outcome in
            partialResult[OccurrenceId(task: outcome.task, startDate: outcome.occurrenceStartDate)] = outcome
        }
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
                    .map { occurrence -> Event in
                        if let outcomesByOccurrence {
                            if let outcome = outcomesByOccurrence[OccurrenceId(task: task, startDate: occurrence.start)] {
                                Event(task: task, occurrence: occurrence, outcome: .value(outcome))
                            } else {
                                Event(task: task, occurrence: occurrence, outcome: .createWith(self))
                            }
                        } else {
                            Event(task: task, occurrence: occurrence, outcome: .preventCreation)
                        }
                    }
            }
            .sorted { lhs, rhs in
                lhs.occurrence < rhs.occurrence
            }
    }
    
    func hasEventOccurrence(in range: Range<Date>, tasks: some Sequence<Task>) -> Bool {
        tasks
            .lazy
            .compactMap { $0.schedule.nextOccurrence(in: range) }
            .contains { _ in true }
    }
    
    func queryEventsAnchor(
        for range: Range<Date>,
        predicate taskPredicate: Predicate<Task> = #Predicate { _ in true }
    ) throws -> Set<PersistentIdentifier> {
        let taskIdentifier = try queryTaskIdentifiers(with: inRangePredicate(for: range), combineWith: taskPredicate)
        let outcomeIdentifiers = try queryOutcomeIdentifiers(for: range, predicate: taskPredicate)
        
        return taskIdentifier.union(outcomeIdentifiers)
    }
}


extension Scheduler {
    @MainActor
    public final class OutcomeSubscription: Sendable {
        private let id: UUID
        private nonisolated(unsafe) weak var scheduler: Scheduler? // safe as reference counting is atomic and we do not mutate otherwise
        
        init(id: UUID, scheduler: Scheduler) {
            self.id = id
            self.scheduler = scheduler
        }
        
        deinit {
            guard let scheduler else {
                return
            }
            let id = id
            _Concurrency.Task { @MainActor in
                scheduler.outcomeObservers.removeValue(forKey: id)
            }
        }
    }
    
    /// Subscribes to save events on the scheduler's internal SwiftData ModelContext, using the specified closure.
    @_spi(APISupport)
    public func sinkDidSavePublisher(into consume: @escaping @MainActor (Notification) -> Void) throws -> AnyCancellable {
        let context = try context
        return NotificationCenter.default.publisher(for: ModelContext.didSave, object: context)
            .sink { notification in
                // We use the mainContext. Therefore, the vent will always be called from the main actor
                MainActor.assumeIsolated {
                    consume(notification)
                }
            }
    }
    
    /// Registers an observer function that gets called when new ``Outcome``s are created within the Scheduler.
    ///
    /// - parameter handler: A closure which will get invoked every time a new ``Outcome`` is added to the ``Scheduler``.
    /// - returns: An opaque handle, to which the lifetime of the observation is tied.
    @_spi(APISupport)
    public func observeNewOutcomes(_ handler: @MainActor @escaping (Outcome) -> Void) -> OutcomeSubscription {
        let id = UUID()
        outcomeObservers[id] = handler
        return OutcomeSubscription(id: id, scheduler: self)
    }
}

// MARK: - Fetch Implementations

extension Scheduler {
    func hasTasksWithNotifications(for range: PartialRangeFrom<Date>) throws -> Bool {
        let rangePredicate = inPartialRangeFromPredicate(for: range)
        let descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { task in
                rangePredicate.evaluate(task) && task.scheduleNotifications
            }
        )
        return try context.fetchCount(descriptor) > 0
    }

    private func queryTasks(
        with basePredicate: Predicate<Task>,
        combineWith userPredicate: Predicate<Task>,
        sortBy sortDescriptors: [SortDescriptor<Task>],
        fetchLimit: Int? = nil, // swiftlint:disable:this function_default_parameter_at_end
        prefetchOutcomes: Bool
    ) throws -> [Task] {
        var descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { task in
                basePredicate.evaluate(task) && userPredicate.evaluate(task)
            },
            sortBy: sortDescriptors
        )
        descriptor.fetchLimit = fetchLimit
        descriptor.sortBy.append(SortDescriptor(\.effectiveFrom, order: .forward))
        // make sure querying the next version is always efficient
        descriptor.relationshipKeyPathsForPrefetching = [\.nextVersion]
        if prefetchOutcomes {
            descriptor.relationshipKeyPathsForPrefetching.append(\.outcomes)
        }
        return try context.fetch(descriptor)
    }

    private func queryOutcomes(for range: Range<Date>, predicate taskPredicate: Predicate<Task>) throws -> [Outcome] {
        var descriptor = FetchDescriptor<Outcome>(
            predicate: #Predicate { outcome in
                // Since, for some reason, `range.contains(outcome.occurrenceStartDate)` doesn't work in a #Predicate
                // (it just filters out everything, even if the start date does in fact fall into the range),
                // we instead need to rewrite what could otherwise be a `contains` call into explicit checks against the range's lower and upper bound.
                // See also: https://github.com/StanfordSpezi/SpeziScheduler/pull/55#issuecomment-2667153659
                // swiftlint:disable:next line_length
                range.lowerBound <= outcome.occurrenceStartDate && outcome.occurrenceStartDate < range.upperBound && taskPredicate.evaluate(outcome.task)
            }
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.task]
        return try context.fetch(descriptor)
    }

    private func queryTaskIdentifiers(
        with basePredicate: Predicate<Task>,
        combineWith userPredicate: Predicate<Task>
    ) throws -> Set<PersistentIdentifier> {
        let descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { task in
                basePredicate.evaluate(task) && userPredicate.evaluate(task)
            }
        )
        return try Set(context.fetchIdentifiers(descriptor))
    }

    private func queryOutcomeIdentifiers(for range: Range<Date>, predicate taskPredicate: Predicate<Task>) throws -> Set<PersistentIdentifier> {
        let descriptor = FetchDescriptor<Outcome>(
            predicate: #Predicate { outcome in
                // Since, for some reason, `range.contains(outcome.occurrenceStartDate)` doesn't work in a #Predicate
                // (it just filters out everything, even if the start date does in fact fall into the range),
                // we instead need to rewrite what could otherwise be a `contains` call into explicit checks against the range's lower and upper bound.
                // See also: https://github.com/StanfordSpezi/SpeziScheduler/pull/55#issuecomment-2667153659
                // swiftlint:disable:next line_length
                range.lowerBound <= outcome.occurrenceStartDate && outcome.occurrenceStartDate < range.upperBound && taskPredicate.evaluate(outcome.task)
            }
        )
        return try Set(context.fetchIdentifiers(descriptor))
    }
}

// MARK: - Predicate Creation

extension Scheduler {
    private func inRangePredicate(for range: Range<Date>) -> Predicate<Task> {
        #Predicate<Task> { task in
            if let effectiveTo = task.nextVersion?.effectiveFrom {
                task.effectiveFrom < range.upperBound
                    && range.lowerBound < effectiveTo
            } else {
                // task lifetime is effectively an `PartialRangeFrom`. So all we do is to check if the `range` overlaps with the lower bound
                task.effectiveFrom < range.upperBound
            }
        }
    }

    private func inPartialRangeFromPredicate(for range: PartialRangeFrom<Date>) -> Predicate<Task> {
        #Predicate<Task> { task in
            if let effectiveTo = task.nextVersion?.effectiveFrom {
                task.effectiveFrom <= range.lowerBound
                    && range.lowerBound < effectiveTo
            } else {
                task.effectiveFrom <= range.lowerBound
            }
        }
    }

    private func inClosedRangePredicate(for range: ClosedRange<Date>) -> Predicate<Task> {
        #Predicate<Task> { task in
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

extension Scheduler {
    public enum DataError: Error {
        /// No model container present.
        ///
        /// The container failed to initialize at startup. The `underlying` error is the error occurred when trying to initialize the container.
        case invalidContainer(_ underlying: any Error)
        /// An updated Task cannot shadow the outcomes of a previous task version.
        ///
        /// Make sure the ``Task/effectiveFrom`` date is larger than the start that of the latest completed event.
        case shadowingPreviousOutcomes
        /// Trying to modify a task that is already super-seeded by a newer version.
        ///
        /// This error is thrown if you are trying to modify a task version that is already outdated. Make sure to always apply updates to the newest version of a task.
        case nextVersionAlreadyPresent
    }
}


extension Scheduler.DataError: LocalizedError {
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


extension Sequence {
    /// Returns the offset of the position of `element`'s first occurrence within the sequence.
    ///
    /// - Precondition: It must either be guaranteed that the sequence contains the element at some position, or that the sequence is finite.
    fileprivate func firstOffset(of element: Element) -> Int? where Element: Equatable {
        var offset = 0
        for elem in self {
            if elem == element {
                return offset
            } else {
                offset += 1
            }
        }
        return nil
    }
}


// swiftlint:disable:this file_length
