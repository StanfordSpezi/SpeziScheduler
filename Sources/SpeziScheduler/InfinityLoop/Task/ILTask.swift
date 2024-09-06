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
/// A task represents some form of action or work that a patient or user is supposed to perform. It includes a
/// ``title`` and ``instructions``.
/// A task might occur once or multiple times. The occurrence of a task is referred to as an ``Event``.
/// The ``Schedule`` defines when and how often a task reoccurs.
///
/// ### Versioning
/// Tasks are stored in an append-only format. If you want to modify the contents of a task (e.g., the schedule, title or instructions), you create a new version of the task
/// and set the ``effectiveFrom`` to indicate the date and time at which the updated version becomes effective. Only the newest task version can be modified.
/// You can retrieve the chain of versions using the ``previousVersion`` and ``nextVersion`` properties.
///
/// ### Additional Information
///
/// Tasks support to store additional information. 
///
/// ## Topics
/// ### Properties
/// - ``id``
/// - ``title``
/// - ``instructions``
/// - ``schedule``
///
/// ### Modify a task
/// - ``ILScheduler/createOrUpdateTask(id:title:instructions:schedule:effectiveFrom:with:)``
/// - ``createUpdatedVersion(title:instructions:schedule:effectiveFrom:with:)``
///
/// ### Storing additional information
/// - ``Context``
/// - ``subscript(dynamicMember:)``
///
/// ### Versioning
/// - ``effectiveFrom``
/// - ``nextVersion``
/// - ``previousVersion``
@Model
@dynamicMemberLookup
public final class ILTask { // TODO: complete Additional Information chapter once that is fully thought out!
    /// The `nextVersion` must be unique. `id` must be unique in combination with the `nextVersion` (e.g., no two task with the same id that have a next version of `nil`).
    #Unique<ILTask>([\.nextVersion], [\.id, \.nextVersion])

    /// Create an index for efficient queries.
    ///
    /// - Index on `id`.
    /// - Index on `effectiveFrom` and `nextVersion` (used for queryTask(...)).
    #Index<ILTask>([\.id], [\.effectiveFrom], [\.effectiveFrom, \.nextVersion])

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

    /// The schedule for the events of this Task.
    public private(set) var schedule: ILSchedule

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

    /// A reference to a previous version of this task.
    ///
    /// The ``effectiveFrom`` date specifies when the previous task is considered outdated and
    /// is replaced by this task.
    @Relationship(inverse: \ILTask.nextVersion)
    public private(set) var previousVersion: ILTask?
    /// A reference to a new version of this task.
    ///
    /// If not `nil`, this reference specifies the next version of this task.
    @Relationship(deleteRule: .deny)
    public private(set) var nextVersion: ILTask?

    // TODO: add support for tags, notes, other default things?
    // TODO: notifications

    /// Additional userInfo stored alongside the task.
    private(set) var userInfo: UserInfoStorage<TaskAnchor>
    @Transient private var userInfoCache = UserInfoStorage<TaskAnchor>.RepositoryCache()

    private init(
        id: String,
        title: String.LocalizationValue,
        instructions: String.LocalizationValue,
        schedule: ILSchedule,
        effectiveFrom: Date,
        context: Context
    ) {
        self.id = id
        self.title = title
        self.instructions = instructions
        self.schedule = schedule
        self.outcomes = []
        self.effectiveFrom = effectiveFrom
        self.userInfo = context.userInfo
        self.userInfoCache = context.userInfoCache
    }

    convenience init(
        id: String,
        title: String.LocalizationValue,
        instructions: String.LocalizationValue,
        schedule: ILSchedule,
        effectiveFrom: Date = .now,
        with contextClosure: (inout Context) -> Void = { _ in }
    ) {
        var context = Context()
        contextClosure(&context)

        self.init(id: id, title: title, instructions: instructions, schedule: schedule, effectiveFrom: effectiveFrom, context: context)
    }

    /// Create a new version of this task if any of the provided values differ.
    ///
    /// A new version of this task is created, if any of the provided parameters differs from the current value of this version of the task.
    /// - Parameters:
    ///   - title: The updated title or `nil` if the title should not be updated.
    ///   - instructions: The updated instructions or `nil` if the instructions should not be updated.
    ///   - schedule: The updated schedule or `nil` if the schedule should not be updated.
    ///   - effectiveFrom: The date this update is effective from.
    ///   - contextClosure: The updated context or `nil` if the context should not be updated.
    /// - Returns: Returns the latest version of the `task` and if the task was updated or created indicated by `didChange`.
    public func createUpdatedVersion(
        title: String.LocalizationValue? = nil,
        instructions: String.LocalizationValue? = nil,
        schedule: ILSchedule? = nil,
        effectiveFrom: Date = .now,
        with contextClosure: ((inout Context) -> Void)? = nil
    ) throws -> (task: ILTask, didChange: Bool) {
        try createUpdatedVersion(
            skipShadowCheck: false,
            title: title,
            instructions: instructions,
            schedule: schedule,
            effectiveFrom: effectiveFrom,
            with: contextClosure
        )
    }

    func createUpdatedVersion(
        skipShadowCheck: Bool,
        title: String.LocalizationValue? = nil,
        instructions: String.LocalizationValue? = nil,
        schedule: ILSchedule? = nil,
        effectiveFrom: Date = .now,
        with contextClosure: ((inout Context) -> Void)? = nil
    ) throws -> (task: ILTask, didChange: Bool) {
        let context: Context?
        if let contextClosure {
            var context0 = Context()
            contextClosure(&context0)
            context = context0
        } else {
            context = nil
        }

        guard (title != nil && title != self.title)
                || (instructions != nil && instructions != self.instructions)
                || (schedule != nil && schedule != self.schedule)
                || (context != nil && context?.userInfo != self.userInfo) else {
            return (self, false) // nothing changed
        }

        if nextVersion != nil {
            throw ILScheduler.DataError.nextVersionAlreadyPresent
        }

        // Caller signaled it already performed this check. Great to avoid lazily loading ALL associated outcomes.
        if !skipShadowCheck {
            guard outcomes.allSatisfy({ outcome in
                outcome.occurrenceStartDate < effectiveFrom
            }) else {
                // an updated task cannot shadow already recorded outcomes of a previous task version
                throw ILScheduler.DataError.shadowingPreviousOutcomes
            }
        }

        let newVersion = ILTask(
            id: id,
            title: title ?? self.title,
            instructions: instructions ?? self.instructions,
            schedule: schedule ?? self.schedule,
            effectiveFrom: effectiveFrom,
            context: context ?? Context()
        )


        // @EventQuery is implicitly observing the `nextVersion` property. So we do not necessarily need to save the model here for it to update
        self.nextVersion = newVersion
        // TODO: do i need to set the previous version? test that, otherwise just set it
        
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


extension ILTask {
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

        /// Retrieve the value for a given task storage key.
        /// - Parameter source: The storage key type.
        /// - Returns: The value or `nil` if there isn't currently a value stored in the context.
        public subscript<Source: TaskStorageKey>(_ source: Source.Type) -> Source.Value? {
            get {
                userInfo.get(source, cache: &box.userInfoCache)
            }
            set {
                userInfo.set(source, value: newValue, cache: &box.userInfoCache)
            }
        }
        // TODO: overload for computed, default providing knowledge sources etc?
    }
}
