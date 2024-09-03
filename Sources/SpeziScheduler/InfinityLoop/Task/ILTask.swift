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

public enum TaskAnchor: RepositoryAnchor {}


public protocol TaskStorageKey: UserInfoKey where Anchor == TaskAnchor {}


class StoredAsData<Value: Codable> {
    private var decodedValue: Value?

    func initialValue(for value: Value) -> Data {
        do {
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
            preconditionFailure("Failed to decode value: \(error)") // TODO: not ideal!
        }
    }

    func set(_ value: Value, to storage: inout Data) {
        decodedValue = value
        do {
            storage = try PropertyListEncoder().encode(value)
        } catch {
            // TODO: logger
            print("Failed to encode: \(error)")
        }
    }
}


@Model
public final class ILTask {
    #Unique<ILTask>([\.id, \.effectiveFrom, \.nextVersion])

    private var titleResource: Data
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

    // TODO: the relationship makes us require querying all outcomes always!
    /// The list of outcomes associated with this Task.
    @Relationship(deleteRule: .cascade, inverse: \Outcome.task)
    public private(set) var outcomes: [Outcome] // TODO: shall we really allow that? (just make it private and keep it for the cascade rule??)

    /// The date from which is version of the task is effective.
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

    // TODO: additional context? => outcome values (e.g., goals for e.g. rings or just task like questionnaires)
    // TODO: notifications

    /// Additional userInfo stored alongside the task.
    private var userInfo = UserInfoStorage<TaskAnchor>()

    public init(
        id: String,
        title: LocalizedStringResource,
        instructions: LocalizedStringResource,
        schedule: ILSchedule,
        effectiveFrom: Date = .now
    ) {
        self.id = id
        self.title = title
        self.instructions = instructions
        self.schedule = schedule
        self.outcomes = []
        self.effectiveFrom = effectiveFrom
    }

    public subscript<Source: UserInfoKey<TaskAnchor>>(_ source: Source.Type) -> Source.Value? {
        get {
            userInfo.get(source)
        }
        set {
            // TODO: how to handle versioned access?
            userInfo.set(source, value: newValue)
        }
    }

    func addOutcome(_ outcome: Outcome) {
        // TODO: does it automatically set the inverse property?
        outcomes.append(outcome) // automatically saves the outcome to the container
    }

    // TODO: easy startup operation would be; getOrCreate -> updateIfNotCurrent!
    public func createUpdatedVersion(
        title: LocalizedStringResource? = nil, // TODO: doesn't support deleting the title (if we make it optional)
        instructions: LocalizedStringResource? = nil,
        schedule: ILSchedule? = nil,
        effectiveFrom: Date = .now
    ) -> ILTask {
        guard title != nil || instructions != nil || schedule != nil else {
            // TODO: check if there is actually any equatable difference!
            return self
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
            effectiveFrom: effectiveFrom
        )

        // TODO: just check equatability?

        nextVersion = newVersion
        // TODO: do i need to set the previous version?
        return newVersion
    }
}
