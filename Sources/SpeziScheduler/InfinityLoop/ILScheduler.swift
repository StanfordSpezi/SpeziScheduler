//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SwiftData
import SwiftUI
import Foundation


public final class ILScheduler: Module {
    private var container: ModelContainer? // TODO: configure!

    public init() {}

    public func configure() {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true) // TODO: only for tests
        do {
            container = try ModelContainer(for: ILTask.self, Outcome.self, configurations: configuration)
        } catch {
            print("Error::::: \(error)") // TODO: update!
        }
    }

    public func hasTasksConfigured(ids: String...) throws -> Bool {
        // TODO: doesn't help
        guard let container else {
            preconditionFailure("Faield") // TODO: handle
        }

        let set = Set(ids)

        let descriptor = FetchDescriptor<ILTask>(
            predicate: #Predicate { task in
                set.contains(task.id)
            }
        )



        // TODO: not always create a context? what is smarter?
        let context = ModelContext(container)
        return try context.fetchCount(descriptor) == ids.count // TODO: forward errors?
    }

    // TODO: best way to configure initial tasks?
    public func addTasks(_ tasks: ILTask...) {
        self.addTasks(tasks)
    }

    public func deleteTasks(_ tasks: ILTask...) {
        self.deleteTasks(tasks)
    }


    public func addTasks(_ tasks: [ILTask]) {
        guard let container else {
            preconditionFailure("Faield") // TODO: handle
        }
        let context = ModelContext(container)
        for task in tasks {
            context.insert(task)
        }
    }

    public func deleteTasks(_ tasks: [ILTask]) {
        guard let container else {
            preconditionFailure("Faield") // TODO: handle
        }
        let context = ModelContext(container)
        for task in tasks {
            context.delete(task)

            // TODO: we can't delete the history, as a transaction might contain multiple unrelated changes!
        }
    }

    public func queryTasks(for interval: DateInterval) throws -> [ILTask] {
        try self.queryTasks(for: interval.start...interval.end)
    }

    public func queryTasks(for range: ClosedRange<Date>) throws -> [ILTask] {
        let inClosedRangePredicate = #Predicate<ILTask> { task in
            if let effectiveTo = task.effectiveTo {
                range.contains(task.effectiveFrom)
                || (range.lowerBound <= effectiveTo && effectiveTo < range.upperBound)
            } else {
                range.contains(task.effectiveFrom) || task.effectiveFrom <= range.upperBound
            }
        }

        return try queryTask(with: inClosedRangePredicate)
    }


    public func queryTasks(for range: Range<Date>) throws -> [ILTask] {
        let inRangePredicate = #Predicate<ILTask> { task in
            if let effectiveTo = task.effectiveTo {
                range.contains(task.effectiveFrom)
                    || (range.lowerBound <= effectiveTo && effectiveTo <= range.upperBound)
            } else {
                range.contains(task.effectiveFrom) || task.effectiveFrom < range.upperBound
            }
        }

        return try queryTask(with: inRangePredicate)
    }

    private func queryTask(with predicate: Predicate<ILTask>) throws -> [ILTask] { // TODO: re-throws really?
        guard let container else {
            preconditionFailure("Failed") // TODO: make that an error?
        }

        let context = ModelContext(container)

        var descriptor = FetchDescriptor<ILTask>()
        descriptor.predicate = predicate
        descriptor.sortBy = [SortDescriptor(\.effectiveFrom, order: .forward)] // TODO: support custom sorting?

        // TODO: CareKit just retrieves ALL tasks and filters after the fact?

        // TODO: organize this more, e.g., just return the head versions? (group by identifier?)
        return try context.fetch(descriptor)
    }
}


struct SomeView: View {
    // TODO: we kinda want to filter for events and not for Tasks?
    // TODO: scheduler needs to inject the global model context into the scene???

    // TODO: typically we want to get all events for a day?

    // TODO: filter and sort!

    // TODO: there can only be one Model container!
    @Query(
        filter: #Predicate<ILTask> { $0.id == "asdf" },
        sort: \.id,
        animation: .easeInOut
    )
    var asdf: [ILTask]

    var body: some View {
        EmptyView()
    }

    private(set) var asdf2: SwiftData.Query<[ILTask].Element, [ILTask]> = .init(
        filter: #Predicate<ILTask> {
            $0.id == "asdf"
        },
        sort: \.id,
        animation: .easeInOut)
}
