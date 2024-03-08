//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
@_spi(Spezi) import SpeziScheduler // swiftlint:disable:this attributes


typealias TestAppScheduler = Scheduler<String>


class TestAppDelegate: SpeziAppDelegate {
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
        }
    }
}
