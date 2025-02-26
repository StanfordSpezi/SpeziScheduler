//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Combine
import SwiftData
import SwiftUI


/// Query events in your SwiftUI view.
///
/// Use this property wrapper in your SwiftUI view to query a list of ``Event``s for a given date range.
///
/// ```swift
/// struct EventList: View {
///     @EventQuery(in: .today..<Date.tomorrow)
///     private var events
///
///     var body: some View {
///         List(events) { event in
///             InstructionsTile(event)
///         }
///     }
/// }
/// ```
///
/// - Tip: If the query returns an error for whatever reason, the error will be stored in the ``Binding/fetchError`` property (access via the binding like `$events.fetchError`).
///
/// ## Topics
///
/// ### Retrieve Events
/// - ``wrappedValue``
///
/// ### Fetch Error
/// - ``Binding/fetchError``
/// - ``Binding``
/// - ``projectedValue``
@propertyWrapper
@MainActor
public struct EventQuery {
    private struct Configuration {
        let range: Range<Date>
        let taskPredicate: Predicate<Task>
    }

    @Observable
    @MainActor
    fileprivate final class Storage {
        var viewUpdate: UInt64 = 0
        @ObservationIgnored var cancelable: AnyCancellable?

        @ObservationIgnored var fetchedEvents: [Event] = []
        @ObservationIgnored var fetchedIdentifiers: Set<PersistentIdentifier> = []
    }


    /// Binding to the `EventQuery`.
    public struct Binding {
        /// The range for which the query fetches events.
        public let range: Range<Date>
        
        /// An error encountered during the most recent attempt to fetch events.
        ///
        /// This property contains the error from the most recent fetch. It is `nil` if the most recent fetch succeeded.
        /// Access this property via the binding of the `EventQuery`.
        ///
        /// ```swift
        /// struct EventList: View {
        ///     @EventQuery(in: .today..<Date.tomorrow)
        ///     private var events
        ///
        ///     var body: some View {
        ///         if let error = $events.fetchError {
        ///             // ... display the error
        ///         }
        ///     }
        /// }
        /// ```
        public fileprivate(set) var fetchError: (any Error)?
    }


    @Environment(Scheduler.self)
    private var scheduler

    private let configuration: Configuration
    private let storage = Storage()
    private var binding: Binding

    /// The fetched events.
    ///
    /// If the most recent fetch failed due to a ``Binding/fetchError``, this property hold the results from the last successful fetch. If the first fetch attempt fails,
    /// an empty array is returned.
    public var wrappedValue: [Event] {
        _ = storage.viewUpdate // access the viewUpdate to make sure the view is tied to this observable
        return storage.fetchedEvents
    }

    /// Retrieves the binding of the event query.
    public var projectedValue: Binding {
        _ = storage.viewUpdate
        return binding
    }

    
    /// Create a new event query.
    /// - Parameters:
    ///   - range: The date range to query events for.
    ///   - predicate: Optional `Predicate` allowing you to filter which events should be included in the query, based on their ``Task``.
    public init(
        in range: Range<Date>,
        predicate: Predicate<Task> = #Predicate { _ in true }
    ) {
        configuration = Configuration(range: range, taskPredicate: predicate)
        binding = Binding(range: range)
    }
}


extension EventQuery: DynamicProperty {
    public mutating nonisolated func update() {
        // This is not really ideal, however we require MainActor isolation and `DynamicProperty` doesn't annotate this guarantee
        // even though it will always be called from the main thread.
        // `EventQuery` is a non-Sendable type that must be initialized on the MainActor. This doesn't guarantee that
        // update will always be called on the Main thread (you can still `send` non-sendable values), however, it makes it harder to do.
        // If one ends up calling this on a different actor, they made it on purpose. This is fine for us.
        MainActor.assumeIsolated {
            doUpdate()
        }
    }

    private mutating func doUpdate() {
        // we cannot set @State in the update method (or anything that calls nested update() method!)

        if storage.cancelable == nil {
            do {
                storage.cancelable = try scheduler.sinkDidSavePublisher { [storage] _ in
                    storage.viewUpdate &+= 1
                }
            } catch {
                binding.fetchError = error
                return
            }
        }


        // The update model for the Event Query:
        //  - All Models are Observable. Therefore, views will automatically update if they use anything that changes over the lifetime of the model.
        //   Most importantly, we access the `nextVersion` of each Task in the `queryEvents` method. Inserting a new task is therefore covered by
        //   observation.
        //  - Should there be any completely new task, it triggers our `didSave` publisher above (new tasks are always saved immediately).
        //  - Adding outcomes results in a call to the `save()` method. These updates are, therefore, also covered.

        do {
            // We always keep track of the set of models we are interested in. Only if that changes we query the "real thing".
            // Creating `Event` instances also incurs some overhead and sorting.
            // Querying just the identifiers can be up to 10x faster.
            let anchor = try scheduler.queryEventsAnchor(for: configuration.range, predicate: configuration.taskPredicate)

            guard anchor != storage.fetchedIdentifiers else {
                binding.fetchError = nil
                return
            }

            // Fetch also has a `batchSize` property we could explore in the future. It returns the results as a `FetchResultsCollection`.
            // It isn't documented how it works exactly, however, one could assume that it lazily loads (or just initializes) model objects
            // when iterating through the sequence. However, it probably doesn't really provide any real benefit. Users are expected to be interested
            // in all the results they query for (after all the provide a predicate). Further, we would need to adjust the underlying
            // type of the property wrapper to return a collection of type `FetchResultsCollection`.
            let events = try scheduler.queryEvents(for: configuration.range, predicate: configuration.taskPredicate)

            storage.fetchedEvents = events
            storage.fetchedIdentifiers = anchor
            binding.fetchError = nil
        } catch {
            binding.fetchError = error
        }
    }
}
