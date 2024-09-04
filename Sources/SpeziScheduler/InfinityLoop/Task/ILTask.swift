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

// TODO: there are two concepts (ending a task vs. deleting a task (with all of its previous versions)?)


class StoredAsData<Value: Codable> {
    private var decodedValue: Value?

    func initialValue(for value: Value) -> Data {
        do {
            decodedValue = value
            return try PropertyListEncoder().encode(value)
        } catch {
            // TODO: should this crash?
            // TODO: logger

            return Data()
        }
    }

    func get(from storage: inout Data) -> Value {
        if let decodedValue {
            return decodedValue
        }

        do {
            let value = try PropertyListDecoder().decode(Value.self, from: storage)
            decodedValue = value
            return value
        } catch {
            preconditionFailure("Failed to decode value for data \(storage): \(error)") // TODO: not ideal!
        }
    }

    func set(_ value: Value, to storage: inout Data) {
        decodedValue = value
        do {
            storage = try PropertyListEncoder().encode(value)
        } catch {
            // TODO: logger
            preconditionFailure("Failed to encode value \(value): \(error)")
        }
    }
}


@Model
@dynamicMemberLookup
public final class ILTask {
    /// The `nextVersion` must be unique. `id` must be unique in combination with the `nextVersion` (e.g., no two task with the same id that have a next version of `nil`).
    #Unique<ILTask>([\.nextVersion], [\.id, \.nextVersion])

    /// Create an index for efficient queries.
    ///
    /// - Index on `id`.
    /// - Index on `effectiveFrom` and `nextVersion` (used for queryTask(...)).
    #Index<ILTask>([\.id], [\.effectiveFrom], [\.effectiveFrom, \.nextVersion])

    /// The LocalizedStringResource encoded, as we cannot store Locale with SwiftData.
    private var titleResource: Data
    /// The LocalizedStringResource encoded, as we cannot store Locale with SwiftData.
    private var instructionsResource: Data

    @Transient private var titleStorage = StoredAsData<LocalizedStringResource>()
    @Transient private var instructionsStorage = StoredAsData<LocalizedStringResource>()

    /// The identifier for this task.
    ///
    /// This is a identifier for this task (e.g., `"social-support-questionnaire"`).
    public private(set) var id: String
    /// The user-visible title for this task.
    public private(set) var title: LocalizedStringResource {
        @storageRestrictions(initializes: _titleResource, accesses: _$backingData, titleStorage)
        init(initialValue) {
            _titleResource = .init()
            _$backingData.setValue(forKey: \.titleResource, to: titleStorage.initialValue(for: initialValue))
        }
        get {
            titleStorage.get(from: &titleResource)
        }
        set {
            titleStorage.set(newValue, to: &titleResource)
        }
    }
    /// Instructions for this task.
    ///
    /// Instructions might describe the purpose for this task.
    public private(set) var instructions: LocalizedStringResource {
        @storageRestrictions(initializes: _instructionsResource, accesses: _$backingData, instructionsStorage)
        init(initialValue) {
            _instructionsResource = .init()
            _$backingData.setValue(forKey: \.instructionsResource, to: instructionsStorage.initialValue(for: initialValue))
        }
        get {
            instructionsStorage.get(from: &instructionsResource)
        }
        set {
            instructionsStorage.set(newValue, to: &instructionsResource)
        }
    }

    /// The schedule for the events of this Task.
    public private(set) var schedule: ILSchedule

    /// The list of outcomes associated with this Task.
    ///
    /// - Note: SwiftData lazily loads relationship data. If you do not specify `prefetchOutcomes` when querying the Task, retrieving this property might require
    ///     fetching all relationship data from disk first.
    @Relationship(deleteRule: .cascade, inverse: \Outcome.task)
    public private(set) var outcomes: [Outcome]
    // TODO: shall we really allow that? (just make it private and keep it for the cascade rule??)

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

    // TODO: notifications

    /// Additional userInfo stored alongside the task.
    private(set) var userInfo: UserInfoStorage<TaskAnchor> // TODO: investigate if we can store it as a model an allow predicates this way?
    @Transient private var userInfoCache = UserInfoStorage<TaskAnchor>.RepositoryCache()

    private init(
        id: String,
        title: LocalizedStringResource,
        instructions: LocalizedStringResource,
        schedule: ILSchedule,
        effectiveFrom: Date = .now,
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

    public convenience init(
        id: String,
        title: LocalizedStringResource,
        instructions: LocalizedStringResource,
        schedule: ILSchedule,
        effectiveFrom: Date = .now,
        with contextClosure: (inout Context) -> Void = { _ in }
    ) {
        var context = Context()
        contextClosure(&context)

        self.init(id: id, title: title, instructions: instructions, schedule: schedule, effectiveFrom: effectiveFrom, context: context)
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<Context, Value>) -> Value {
        // we cannot store Context directly in the Model, as it contains a class property which SwiftData cannot ignore :(
        let context = Context(userInfo: userInfo, userInfoCache: userInfoCache)
        return context[keyPath: keyPath]
    }


    func addOutcome(_ outcome: Outcome) {
        // TODO: does it automatically set the inverse property?
        outcomes.append(outcome) // automatically saves the outcome to the container
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
        title: LocalizedStringResource? = nil,
        instructions: LocalizedStringResource? = nil,
        schedule: ILSchedule? = nil,
        effectiveFrom: Date = .now,
        with contextClosure: ((inout Context) -> Void)? = nil
    ) -> (task: ILTask, didChange: Bool) {
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

        // TODO: make this throwing not crashing?
        // TODO: allow to delete those, or override this setting to not have this throwing?
        precondition(
            outcomes.allSatisfy { outcome in
                outcome.occurrenceStartDate < effectiveFrom
            },
            """
            "An updated Task cannot shadow the outcomes of a previous task. \
            Make sure the `effectiveFrom` is larger than the start that of the latest completed event.
            """
        )

        let newVersion = ILTask(
            id: id,
            title: title ?? self.title,
            instructions: instructions ?? self.instructions,
            schedule: schedule ?? self.schedule,
            effectiveFrom: effectiveFrom,
            context: context ?? Context()
        )

        // TODO: next version cannot be already set!
        nextVersion = newVersion
        // TODO: do i need to set the previous version?
        return (newVersion, true)
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

        public subscript<Source: TaskStorageKey>(_ source: Source.Type) -> Source.Value? {
            get {
                userInfo.get(source, cache: &box.userInfoCache)
            }
            set {
                userInfo.set(source, value: newValue, cache: &box.userInfoCache)
            }
        }
    }
}
