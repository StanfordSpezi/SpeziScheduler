//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
@_spi(Spezi)
@_spi(TestingSupport)
import SpeziScheduler
import SwiftData


typealias TestAppScheduler = Scheduler<String>

final class TestAppILScheduler: Module { // TODO: do that or use the sample data? => move into file!
    @Dependency(ILScheduler.self)
    private var scheduler

    init() {}


    func configure() {
        do {
            // TODO: or just use the sample data?
            try scheduler.createOrUpdateTask(
                id: "test-task",
                title: "Social Support Questionnaire",
                instructions: "Please fill out the Social Support Questionnaire every day.",
                schedule: .daily(hour: 16, minute: 0, startingAt: .today),
                effectiveFrom: .today
            )
        } catch {
            // TODO: error handler?
        }
    }
}


class TestAppDelegate: SpeziAppDelegate {
    private var sampleData: ModelContainer {
        do {
            return try SchedulerSampleData.makeSharedContext()
        } catch {
            preconditionFailure("Failed to instantiate sample data: \(error)")
        }
    }

    override var configuration: Configuration {
        Configuration {
            // ensure storage is not mocked even though we are running within the simulator
            SchedulerStorage(for: TestAppScheduler.self, mockedStorage: false)
            TestAppScheduler(
                tasks: [
                    Task(
                        title: "Original Task",
                        description: "Original Task",
                        schedule: Schedule(
                            start: .now,
                            repetition: .matching(.init(nanosecond: 0)), // Every full second
                            end: .numberOfEvents(1)
                        ),
                        context: "Original Task!"
                    )
                ]
            )

            // TODO: ILScheduler(testingContainer: sampleData)
            ILScheduler()
            TestAppILScheduler()
        }
    }
}
