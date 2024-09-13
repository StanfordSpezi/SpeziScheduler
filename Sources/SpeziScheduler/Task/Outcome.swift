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


/// The outcome of an event.
///
/// Each ``Event`` of a ``Task`` might be completed by supplying an `Outcome`.
/// There might always just be a single outcome associated with a single event.
///
/// ### Storing Additional Information
///
/// An outcome supports storing additional metadata information (e.g., the measurement value or medication).
///
/// - Tip: Refer to the ``Property()`` macro on how to create new data types that can be stored alongside an outcome.
///
/// You provide the additional outcome values upon completion of an event (see ``Event/complete(with:)``.
/// Below is a short code example that sets a custom `measurement` property to the weight measurement that was received
/// from a connected weight scale.
///
/// ```swift
/// event.complete { outcome in
///     outcome.measurement = weightMeasurement
/// }
/// ```
///
/// ## Topics
///
/// ### Properties
/// - ``id``
/// - ``completionDate``
/// - ``occurrence``
/// - ``event``
/// - ``task``
@Model
public final class Outcome {
    #Index<Outcome>([\.id], [\.occurrenceStartDate])

    /// The id of the outcome.
    @Attribute(.unique)
    public var id: UUID

    /// The completion date of the outcome.
    public private(set) var completionDate: Date
    /// The date of the occurrence.
    ///
    /// We use the occurrence date to match the outcome to the ``Occurrence`` instance.
    /// `Date` is independent of any specific calendar or time zone, representing a time interval relative to an absolute reference date.
    /// Therefore, you can think of this property as an occurrence index that is monotonic but not necessarily continuous.
    private(set) var occurrenceStartDate: Date

    /// The associated task of the outcome.
    public private(set) var task: Task

    /// The occurrence of the event the outcome is associated with.
    public var occurrence: Occurrence {
        // correct would probably be to call `task.schedule.occurrence(forStartDate:)` and check if this still exists
        // but assuming the occurrence exists and having a non-optional return type is just easier
        Occurrence(start: occurrenceStartDate, schedule: task.schedule)
    }

    /// The associated event for this outcome.
    public var event: Event {
        Event(task: task, occurrence: occurrence, outcome: .value(self))
    }

    /// Additional userInfo stored alongside the outcome.
    private var userInfo = UserInfoStorage<OutcomeAnchor>()
    @Transient private var userInfoCache = UserInfoStorage<OutcomeAnchor>.RepositoryCache()

    init(task: Task, occurrence: Occurrence) {
        self.id = UUID()
        self.completionDate = .now
        self.task = task
        self.occurrenceStartDate = occurrence.start
    }
}


extension Outcome {
    /// Retrieve or set the value for a given storage key.
    /// - Parameter source: The storage key.
    /// - Returns: The value or `nil` if there isn't currently a value stored in the outcome.
    @_documentation(visibility: internal)
    public subscript<Source: OutcomeStorageKey>(_ source: Source.Type) -> Source.Value? {
        get {
            userInfo.get(source, cache: &userInfoCache)
        }
        set {
            userInfo.set(source, value: newValue, cache: &userInfoCache)
        }
    }

    /// Retrieve or set the value for a given storage key.
    /// - Parameters:
    ///   - source: The storage key type.
    ///   - defaultValue: A default value that is returned if there isn't a value stored.
    /// - Returns: The value or the default value if there isn't currently a value stored in the context.
    @_documentation(visibility: internal)
    public subscript<Source: OutcomeStorageKey>(_ source: Source.Type, default defaultValue: @autoclosure () -> Source.Value) -> Source.Value {
        get {
            userInfo.get(source, cache: &userInfoCache) ?? defaultValue()
        }
        set {
            userInfo.set(source, value: newValue, cache: &userInfoCache)
        }
    }
}


extension Outcome: CustomStringConvertible {
    public var description: String {
        """
        Outcome(\
        id: \(id), \
        completionDate: \(completionDate), \
        occurrence: \(occurrence), \
        task: \(task), \
        userInfo: \(userInfo)\
        )
        """
    }
}
