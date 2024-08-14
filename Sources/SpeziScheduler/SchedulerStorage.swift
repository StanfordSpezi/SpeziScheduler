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


@_spi(Spezi)
/// Underlying Storage module for the `Scheduler`.
public actor SchedulerStorage<Context: Codable & Sendable>: Module, DefaultInitializable, AnyStorage {
    private let logger = Logger(subsystem: "edu.stanford.spezi.scheduler", category: "Storage")

    @Dependency(LocalStorage.self)
    private var localStorage

    private let storageIsMocked: Bool
    @MainActor let taskList = TaskList<Context>()

    private var debounceTask: _Concurrency.Task<Void, Never>? {
        willSet {
            debounceTask?.cancel()
        }
    }
    

    public init() {
        #if targetEnvironment(simulator)
        self.init(mockedStorage: true)
        #else
        self.init(mockedStorage: false)
        #endif
    }

    public init(for scheduler: Scheduler<Context>.Type = Scheduler<Context>.self, mockedStorage: Bool) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.storageIsMocked = mockedStorage
    }


    func loadTasks() -> [Task<Context>]? {
        // swiftlint:disable:previous discouraged_optional_collection
        if storageIsMocked {
            logger.debug("""
                         Storage is disabled as we are running int the simulator. No tasks were loaded.

                         To enable storage even if running within the simulator you can add the following module to your Spezi configuration:
                         SchedulerStorage(for: Scheduler<\(Context.self)>.self, mockedStorage=false)
                         """)
            return nil
        }

        do {
            return try localStorage.read([Task<Context>].self, storageKey: Constants.taskStorageKey)
        } catch {
            logger.error("Could not retrieve tasks from storage for the scheduler module: \(error)")
        }
        return nil
    }

    @MainActor
    func storeTasks() async {
        let taskList = taskList
        await _storeTasks(taskList: taskList)
    }

    private func _storeTasks(taskList: TaskList<Context>) async {
        if storageIsMocked {
            logger.debug("""
                         Storage is disabled as we are running int the simulator. No tasks were saved.
                         
                         To enable storage even if running within the simulator you can add the following module to your Spezi configuration:
                         SchedulerStorage(for: Scheduler<\(Context.self)>.self, mockedStorage=false)
                         """)
            return
        }

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
        debounceTask = _Concurrency.Task { @MainActor in
            try? await _Concurrency.Task.sleep(for: .milliseconds(500))

            guard !_Concurrency.Task.isCancelled else {
                return
            }

            await storeTasks()
        }
    }
}
