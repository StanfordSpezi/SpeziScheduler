//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation
import SwiftData


/// A task that a user is supposed to perform.
///
/// A task represents some form of action or work that a patient or user is supposed to perform. It includes a ``title`` and ``instructions``.
/// A task might occur once or multiple times. The occurrence of a task is referred to as an ``Event``.
/// The ``Schedule`` defines when and how often a task reoccurs.
///
/// - Note: SpeziScheduler can automatically schedule notifications for your events. Refer to the documentation of the ``SchedulerNotifications`` module for more information.
///
/// ### Versioning
/// Tasks are stored in an append-only format. If you want to modify the contents of a task (e.g., the schedule, title or instructions), you create a new version of the task
/// and set the ``effectiveFrom`` to indicate the date and time at which the updated version becomes effective. Only the newest task version can be modified.
/// You can retrieve the chain of versions using the ``previousVersion`` and ``nextVersion`` properties.
///
/// ### Storing Additional Information
///
/// Tasks support storing additional metadata information.
///
/// - Tip: Refer to the ``Property(coding:)`` macro on how to create new data types that can be stored alongside a task.
///
/// You can set additional information by supplying an additional closure that modifies the ``Context`` when creating or updating a task.
/// The code example below assume that the `measurementType` exists to store the type of measurement the user should record to complete the task.
///
/// ```swift
/// try scheduler.createOrUpdateTask(
///     id: "record-measurement",
///     title: "Weight Measurement",
///     instructions: "Perform a new weight measurement with your bluetooth scale.",
///     schedule: .daily(hour: 8, minute: 30, startingAt: .today)
/// ) { context in
///     context.measurementType = .weight
/// }
/// ```
///
/// ## Topics
/// ### Properties
/// - ``id``
/// - ``title``
/// - ``instructions``
/// - ``category``
/// - ``schedule``
/// - ``completionPolicy``
/// - ``tags``
/// - ``outcomes``
///
/// ### Notifications
///
/// - ``scheduleNotifications``
/// - ``notificationThread``
///
/// ### Modifying a task
/// - ``Scheduler/createOrUpdateTask(id:title:instructions:category:schedule:completionPolicy:tags:effectiveFrom:with:)``
/// - ``createUpdatedVersion(title:instructions:category:schedule:completionPolicy:scheduleNotifications:notificationThread:tags:effectiveFrom:with:)``
///
/// ### Storing additional information
/// - ``Context``
/// - ``subscript(dynamicMember:)``
///
/// ### Versioning
/// - ``effectiveFrom``
/// - ``nextVersion``
/// - ``previousVersion``
/// - ``isLatestVersion``
/// - ``firstVersion``
@Model
@dynamicMemberLookup
public final class Task {
    /// The `nextVersion` must be unique. `id` must be unique in combination with the `nextVersion` (e.g., no two task with the same id that have a next version of `nil`).
    #Unique<Task>([\.nextVersion], [\.id, \.nextVersion])

    /// Create an index for efficient queries.
    ///
    /// - Index on `id`.
    /// - Index on `effectiveFrom` and `nextVersion` (used for queryTask(...)).
    #Index<Task>([\.id], [\.effectiveFrom], [\.effectiveFrom, \.nextVersion])

    /// The identifier for this task.
    ///
    /// This is a identifier for this task (e.g., `"social-support-questionnaire"`).
    public private(set) var id: String
    /// The user-visible title for this task.
    public private(set) var title: String.LocalizationValue
    /// Instructions for this task.
    ///
    /// Instructions might describe the purpose for this task.
    public private(set) var instructions: String.LocalizationValue

    /// For whatever reason, if we make it type `Category`, SwiftData fails to stored the category.
    /// You save the model, deinit the model class, query the model again and then the category property would just be gone.
    private var categoryValue: String?

    /// The user-visible category of a task.
    ///
    /// Tasks can optionally provide a user-visible category to more clearly communicate the type of task to the user.
    /// UI components can use the category to
    public var category: Category? {
        @storageRestrictions(initializes: _categoryValue, accesses: _$backingData)
        init(initialValue) {
            _categoryValue = .init()
            _$backingData.setValue(forKey: \.categoryValue, to: initialValue?.rawValue)
        }
        get {
            categoryValue.map { Category(rawValue: $0) }
        }
        set {
            categoryValue = newValue?.rawValue
        }
    }

    /// The schedule for the events of this Task.
    public private(set) var schedule: Schedule

    /// The policy to decide when an event can be completed by the user.
    public private(set) var completionPolicy: AllowedCompletionPolicy
    
    /// Automatically schedule notifications for upcoming events.
    ///
    /// If this flag is set to `true`, the ``SchedulerNotifications`` will automatically schedule notifications for the upcoming
    /// events of this task. Refer to the documentation of `SchedulerNotifications` for all necessary steps and configuration in order to use this feature.
    public private(set) var scheduleNotifications: Bool
    
    /// The behavior how task notifications are grouped in the notification center.
    public private(set) var notificationThread: NotificationThread

    /// Tags associated with the task.
    ///
    /// This is a custom list of tags that can be useful to categorize or group tasks and make it easier to query
    /// a certain set of related tasks.
    public private(set) var tags: [String]

    /// The list of outcomes associated with this Task.
    ///
    /// - Note: SwiftData lazily loads relationship data. If you do not specify `prefetchOutcomes` when querying the Task, retrieving this property might require
    ///     fetching all relationship data from disk first.
    @Relationship(deleteRule: .cascade, inverse: \Outcome.task)
    public private(set) var outcomes: [Outcome]

    /// The date from which this version of the task is effective.
    public private(set) var effectiveFrom: Date

    /// Determine if this task is the latest instance.
    public var isLatestVersion: Bool {
        nextVersion == nil // next version is always pre-fetched
    }
    
    /// The latest version of this task.
    ///
    /// This is also the version that will currently be used by the ``Scheduler``.
    public var latestVersion: Task {
        nextVersion?.latestVersion ?? self
    }
    
    /// The first version of this task.
    public var firstVersion: Task {
        previousVersion?.firstVersion ?? self
    }
    
    var allVersions: UnfoldFirstSequence<Task> {
        if let previousVersion {
            return previousVersion.allVersions
        } else {
            return sequence(first: self, next: \.nextVersion)
        }
    }

    /// A reference to a previous version of this task.
    ///
    /// The ``effectiveFrom`` date specifies when the previous task is considered outdated and
    /// is replaced by this task.
    @Relationship(inverse: \Task.nextVersion)
    public private(set) var previousVersion: Task?
    /// A reference to a new version of this task.
    ///
    /// If not `nil`, this reference specifies the next version of this task.
    @Relationship(deleteRule: .cascade)
    public private(set) var nextVersion: Task?

    /// Additional userInfo stored alongside the task.
    private(set) var userInfo: UserInfoStorage<TaskAnchor>
    @Transient private var userInfoCache = UserInfoStorage<TaskAnchor>.RepositoryCache()

    private init(
        id: String,
        title: String.LocalizationValue,
        instructions: String.LocalizationValue,
        category: Category?,
        schedule: Schedule,
        completionPolicy: AllowedCompletionPolicy,
        scheduleNotifications: Bool,
        notificationThread: NotificationThread,
        tags: [String],
        effectiveFrom: Date,
        context: Context
    ) {
        self.id = id
        self.title = title
        self.instructions = instructions
        self.category = category
        self.schedule = schedule
        self.completionPolicy = completionPolicy
        self.scheduleNotifications = scheduleNotifications
        self.notificationThread = notificationThread
        self.outcomes = []
        self.tags = tags
        self.effectiveFrom = effectiveFrom
        self.userInfo = context.userInfo
        self.userInfoCache = context.userInfoCache
    }

    /// Internal convenience init.
    @_spi(Internal)
    public convenience init(
        id: String,
        title: String.LocalizationValue,
        instructions: String.LocalizationValue,
        category: Category?,
        schedule: Schedule,
        completionPolicy: AllowedCompletionPolicy,
        scheduleNotifications: Bool,
        notificationThread: NotificationThread,
        tags: [String],
        effectiveFrom: Date,
        with contextClosure: (inout Context) -> Void = { _ in }
    ) {
        var context = Context()
        contextClosure(&context)

        self.init(
            id: id,
            title: title,
            instructions: instructions,
            category: category,
            schedule: schedule,
            completionPolicy: completionPolicy,
            scheduleNotifications: scheduleNotifications,
            notificationThread: notificationThread,
            tags: tags,
            effectiveFrom: effectiveFrom,
            context: context
        )
    }

    /// Create a new version of this task if any of the provided values differ.
    ///
    /// - Warning: `title` and `instructions` are localizable strings. If you change any of these properties, make sure to maintain the previous
    ///     keys in your String catalog to make sure that previous versions maintain to get displayed for existing users of your application.
    ///
    /// A new version of this task is created, if any of the provided parameters differs from the current value of this version of the task.
    /// - Parameters:
    ///   - title: The updated title or `nil` if the title should not be updated.
    ///   - instructions: The updated instructions or `nil` if the instructions should not be updated.
    ///   - category: The user-visible category information of a task.
    ///   - schedule: The updated schedule or `nil` if the schedule should not be updated.
    ///   - completionPolicy: The policy to decide when an event can be completed by the user.
    ///   - scheduleNotifications: Automatically schedule notifications for upcoming events.
    ///   - notificationThread: The behavior how task notifications are grouped in the notification center.
    ///   - tags: Custom tags associated with the task.
    ///   - effectiveFrom: The date this update is effective from.
    ///   - contextClosure: The updated context or `nil` if the context should not be updated.
    /// - Returns: Returns the latest version of the `task` and if the task was updated or created indicated by `didChange`.
    public func createUpdatedVersion(
        title: String.LocalizationValue? = nil,
        instructions: String.LocalizationValue? = nil,
        category: Category? = nil,
        schedule: Schedule? = nil,
        completionPolicy: AllowedCompletionPolicy? = nil,
        scheduleNotifications: Bool? = nil, // swiftlint:disable:this discouraged_optional_boolean
        notificationThread: NotificationThread? = nil,
        tags: [String]? = nil, // swiftlint:disable:this discouraged_optional_collection
        effectiveFrom: Date = .now,
        with contextClosure: ((inout Context) -> Void)? = nil
    ) throws -> (task: Task, didChange: Bool) {
        try createUpdatedVersion(
            skipShadowCheck: false,
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
    }
    
    
    /// Determines whether an update of the task, based on the specified parameters, would result in a new version of the task.
    func wouldNecessitateNewTaskVersion( // swiftlint:disable:this function_parameter_count
        title: String.LocalizationValue?,
        instructions: String.LocalizationValue?,
        category: Category?,
        schedule: Schedule?,
        completionPolicy: AllowedCompletionPolicy?,
        scheduleNotifications: Bool?, // swiftlint:disable:this discouraged_optional_boolean
        notificationThread: NotificationThread?,
        tags: [String]?, // swiftlint:disable:this discouraged_optional_collection
        effectiveFrom: Date,
        with contextClosure: ((inout Context) -> Void)?
    ) -> Bool {
        let context: Context? = contextClosure.map { apply in
            var context = Context()
            apply(&context)
            return context
        }
        func didChange<V: Equatable>(_ value: V?, for keyPath: KeyPath<Task, V>) -> Bool {
            value != nil && value != self[keyPath: keyPath]
        }
        return didChange(title, for: \.title)
            || didChange(instructions, for: \.instructions)
            || didChange(category, for: \.category)
            || didChange(schedule, for: \.schedule)
            || didChange(completionPolicy, for: \.completionPolicy)
            || didChange(tags, for: \.tags)
            || didChange(scheduleNotifications, for: \.scheduleNotifications)
            || didChange(notificationThread, for: \.notificationThread)
            || didChange(context?.userInfo, for: \.userInfo)
    }

    func createUpdatedVersion( // swiftlint:disable:this function_parameter_count
        skipShadowCheck: Bool,
        title: String.LocalizationValue?,
        instructions: String.LocalizationValue?,
        category: Category?,
        schedule: Schedule?,
        completionPolicy: AllowedCompletionPolicy?,
        scheduleNotifications: Bool?, // swiftlint:disable:this discouraged_optional_boolean
        notificationThread: NotificationThread?,
        tags: [String]?, // swiftlint:disable:this discouraged_optional_collection
        effectiveFrom: Date,
        with contextClosure: ((inout Context) -> Void)?
    ) throws -> (task: Task, didChange: Bool) {
        guard wouldNecessitateNewTaskVersion(
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
            return (self, false)
        }
        
        let context: Context? = contextClosure.map { apply in
            var context = Context()
            apply(&context)
            return context
        }

        if nextVersion != nil {
            throw Scheduler.DataError.nextVersionAlreadyPresent
        }

        // Caller signaled it already performed this check. Great to avoid lazily loading ALL associated outcomes.
        if !skipShadowCheck {
            guard outcomes.allSatisfy({ outcome in
                outcome.occurrenceStartDate < effectiveFrom
            }) else {
                // an updated task cannot shadow already recorded outcomes of a previous task version
                throw Scheduler.DataError.shadowingPreviousOutcomes
            }
        }

        let newVersion = Task(
            id: id,
            title: title ?? self.title,
            instructions: instructions ?? self.instructions,
            category: category ?? self.category,
            schedule: schedule ?? self.schedule,
            completionPolicy: completionPolicy ?? self.completionPolicy,
            scheduleNotifications: scheduleNotifications ?? self.scheduleNotifications,
            notificationThread: notificationThread ?? self.notificationThread,
            tags: tags ?? self.tags,
            effectiveFrom: effectiveFrom,
            context: context ?? Context()
        )

        // @EventQuery is implicitly observing the `nextVersion` property. So we do not necessarily need to save the model here for it to update
        self.nextVersion = newVersion // automatically sets the previous version as well
        assert(
            newVersion.previousVersion === self,
            "Previous version was set to an unexpected value: \(String(describing: newVersion.previousVersion))"
        )

        return (newVersion, true)
    }

    /// Access members of the tasks context.
    ///
    /// This subscript allows to dynamically access members of the ``Context`` of the task.
    ///
    /// - Parameter keyPath: The key path to a property of the `Context`.
    /// - Returns: The value for that property `Context`.
    public subscript<Value>(dynamicMember keyPath: KeyPath<Context, Value>) -> Value {
        // we cannot store Context directly in the Model, as it contains a class property which SwiftData cannot ignore :(
        let context = Context(userInfo: userInfo, userInfoCache: userInfoCache)
        return context[keyPath: keyPath]
    }
}


extension Task {
    /// Additional context information stored alongside the task.
    public struct Context {
        private class Box {
            var userInfoCache: UserInfoStorage<TaskAnchor>.RepositoryCache

            init(userInfoCache: UserInfoStorage<TaskAnchor>.RepositoryCache) {
                self.userInfoCache = userInfoCache
            }
        }

        private(set) var userInfo: UserInfoStorage<TaskAnchor>
        private let box: Box

        var userInfoCache: UserInfoStorage<TaskAnchor>.RepositoryCache {
            box.userInfoCache
        }


        init(userInfo: UserInfoStorage<TaskAnchor> = .init(), userInfoCache: UserInfoStorage<TaskAnchor>.RepositoryCache = .init()) {
            self.userInfo = userInfo
            self.box = Box(userInfoCache: userInfoCache)
        }

        /// Retrieve or set the value for a given storage key.
        /// - Parameter source: The storage key type.
        /// - Returns: The value or `nil` if there isn't currently a value stored in the context.
        @_documentation(visibility: internal)
        public subscript<Source: TaskStorageKey>(_ source: Source.Type) -> Source.Value? {
            get {
                userInfo.get(source, cache: &box.userInfoCache)
            }
            set {
                userInfo.set(source, value: newValue, cache: &box.userInfoCache)
            }
        }


        /// Retrieve or set the value for a given storage key.
        /// - Parameters:
        ///   - source: The storage key type.
        ///   - defaultValue: A default value that is returned if there isn't a value stored.
        /// - Returns: The value or the default value if there isn't currently a value stored in the context.
        @_documentation(visibility: internal)
        public subscript<Source: TaskStorageKey>(_ source: Source.Type, default defaultValue: @autoclosure () -> Source.Value) -> Source.Value {
            get {
                userInfo.get(source, cache: &box.userInfoCache) ?? defaultValue()
            }
            set {
                userInfo.set(source, value: newValue, cache: &box.userInfoCache)
            }
        }
    }
}


extension Task: CustomStringConvertible {
    public var description: String {
        """
        Task(\
        id: \(id), \
        title: \(title), \
        instructions: \(instructions), \
        category: \(category.map { $0.description } ?? "nil"), \
        schedule: \(schedule), \
        completionPolicy: \(completionPolicy), \
        scheduleNotifications: \(scheduleNotifications), \
        notificationThread: \(notificationThread), \
        tags: \(tags), \
        outcomes: <redacted for performance reasons>, \
        effectiveFrom: \(effectiveFrom), \
        hasPreviousVersion: \(previousVersion != nil), \
        hasNextVersion: \(nextVersion != nil), \
        userInfo: \(userInfo)\
        )
        """
    }
}
