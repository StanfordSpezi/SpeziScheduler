//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Algorithms
import Foundation
import SQLite
import SwiftData


struct IOS26StringLocalizationValuesMigration: ~Copyable {
    private struct MigrationError: Error {
        let message: String
    }
    
    fileprivate struct Entry {
        let taskId: String
        /// The task's version, modeled as the index of this particular version of the task, in the ordered list of all its versions.
        let taskVersion: Int
        let title: String.LocalizationValue
        let instructions: String.LocalizationValue
    }
    
    private let entries: [Entry]
    
    init(databaseUrl url: URL) throws {
        let db = try Connection(url.absoluteURL.path, readonly: true) // swiftlint:disable:this identifier_name
        let tasks = Table("ZTASK")
        let primaryKey = SQLite.Expression<Int64>("Z_PK")
        let id = SQLite.Expression<String>("ZID")
        let prevVersion = SQLite.Expression<Int64?>("ZPREVIOUSVERSION")
        let nextVersion = SQLite.Expression<Int64?>("ZNEXTVERSION")
        let titleKey = SQLite.Expression<String>("ZKEY1")
        let titleArguments = SQLite.Expression<Blob>("ZARGUMENTS1")
        let instructionsKey = SQLite.Expression<String>("ZKEY")
        let instructionsArguments = SQLite.Expression<Blob>("ZARGUMENTS")
        entries = try db.prepare(tasks).map { task in
            let title = try String.LocalizationValue.construct(fromKey: task[titleKey], arguments: task[titleArguments])
            let instructions = try String.LocalizationValue.construct(fromKey: task[instructionsKey], arguments: task[instructionsArguments])
            let allTaskVersions: [Row] = try { () -> [Row] in
                var allTasks = Array(try db.prepare(tasks.where(id == task[id])))
                guard let firstTaskIdx = allTasks.firstIndex(where: { $0[prevVersion] == nil }), allTasks.count(where: { $0[prevVersion] == nil }) == 1 else {
                    throw MigrationError(message: "Unable to find first task version")
                }
                var sortedByVersion = [allTasks.remove(at: firstTaskIdx)]
                while let currentTask = sortedByVersion.last, let nextTaskPrimaryKey = currentTask[nextVersion] {
                    guard let nextTaskIdx = allTasks.firstIndex(where: { $0[primaryKey] == nextTaskPrimaryKey }) else {
                        throw MigrationError(message: "Unable to find next task version")
                    }
                    sortedByVersion.append(allTasks.remove(at: nextTaskIdx))
                }
                assert(allTasks.isEmpty)
                return sortedByVersion
            }()
            assert(allTaskVersions.adjacentPairs().allSatisfy { $0[nextVersion] == $1[primaryKey] && $1[prevVersion] == $0[primaryKey] })
            return Entry(
                taskId: task[id],
                taskVersion: allTaskVersions.firstIndex { $0[primaryKey] == task[primaryKey] }!, // swiftlint:disable:this force_unwrapping
                title: title,
                instructions: instructions
            )
        }
    }
    
    consuming func apply(to context: ModelContext) throws {
        for entry in entries {
            let taskId = entry.taskId
            let tasksWithId = try context.fetch(FetchDescriptor<Task>(predicate: #Predicate { $0.id == taskId }))
            precondition(!tasksWithId.isEmpty) // if we have an entry there also must be tasks...
            let task = Array(tasksWithId[0].allVersions)[entry.taskVersion]
            task._updateTitle(entry.title, instructions: entry.instructions)
            try context.save()
        }
    }
}


extension String.LocalizationValue {
    fileprivate enum ConstructionError: Error {
        case unableToReadArguments
    }
    
    fileprivate static func construct(fromKey key: String, arguments: Blob) throws -> String.LocalizationValue {
        guard let argumentsStringValue = String(data: Data(arguments.bytes), encoding: .utf8) else {
            throw ConstructionError.unableToReadArguments
        }
        let json = #"{"key": "\#(key)", "arguments": \#(argumentsStringValue)}"#
        return try JSONDecoder().decode(String.LocalizationValue.self, from: Data(json.utf8))
    }
}
