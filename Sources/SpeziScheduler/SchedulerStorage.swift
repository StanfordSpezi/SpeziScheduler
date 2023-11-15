//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OSLog
import Spezi
import SpeziLocalStorage


protocol AnyStorage {
    func signalChange()
}


actor SchedulerStorage<Context: Codable>: Module, DefaultInitializable, AnyStorage {
    private let logger = Logger(subsystem: "edu.stanford.spezi.scheduler", category: "Storage")

    @Dependency private var localStorage: LocalStorage

    private let taskList: TaskList<Context>

    private var debounceTask: _Concurrency.Task<Void, Never>? {
        willSet {
            debounceTask?.cancel()
        }
    }


    init() {
        self.taskList = TaskList()
    }
    

    init(taskList: TaskList<Context>) {
        self.taskList = taskList
    }


    func loadTasks() -> [Task<Context>]? {
        // swiftlint:disable:previous discouraged_optional_collection
        do {
            return try localStorage.read([Task<Context>].self, storageKey: Constants.taskStorageKey)
        } catch {
            logger.error("Could not retrieve tasks from storage for the scheduler module: \(error)")
        }
        return nil
    }

    func storeTasks() {
        do {
            try localStorage.store(taskList.tasks, storageKey: Constants.taskStorageKey)
        } catch {
            logger.error("Could not persist the tasks of the scheduler module: \(error)")
        }
    }

    nonisolated func signalChange() {
        _Concurrency.Task {
            await debounceCall()
        }
    }

    private func debounceCall() async {
        debounceTask = _Concurrency.Task {
            try? await _Concurrency.Task.sleep(for: .milliseconds(500))

            guard !_Concurrency.Task.isCancelled else {
                return
            }

            storeTasks()

            debounceTask = nil
        }
    }
}
