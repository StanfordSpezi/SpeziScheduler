//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Observation


@Observable
final class TaskList<Context: Codable> {
    var tasks: [Task<Context>]

    init(tasks: [Task<Context>] = []) {
        self.tasks = tasks
    }


    func append(_ element: Task<Context>) {
        tasks.append(element)
    }
}


extension TaskList: Hashable {
    static func == (lhs: TaskList<Context>, rhs: TaskList<Context>) -> Bool {
        lhs.tasks == rhs.tasks
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(tasks)
    }
}


extension TaskList: MutableCollection {
    public var startIndex: Int {
        tasks.startIndex
    }

    public var endIndex: Int {
        tasks.endIndex
    }


    public func index(after index: Int) -> Int {
        tasks.index(after: index)
    }

    public func partition(by belongsInSecondPartition: (Task<Context>) throws -> Bool) rethrows -> Int {
        try tasks.partition(by: belongsInSecondPartition)
    }

    
    public subscript(position: Int) -> Task<Context> {
        _read {
            yield tasks[position]
        }
        set(newValue) {
            tasks[position] = newValue
        }
    }
}
