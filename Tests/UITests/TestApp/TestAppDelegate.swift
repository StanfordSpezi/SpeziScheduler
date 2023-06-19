//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziScheduler


typealias TestAppScheduler = Scheduler<TestAppStandard, String>


class TestAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration(standard: TestAppStandard()) {
            TestAppScheduler(
                tasks: [
                    Task(
                        title: "Original Task",
                        description: "Original Task",
                        schedule: Schedule(
                            start: .now,
                            repetition: .matching(.init(hour: 14, minute: 11)),
                            // repetition: .matching(.init(nanosecond: 0)), // Every full second
                            end: .numberOfEvents(356)
                        ),
                        notifications: true,
                        context: "Original Task!"
                    )
                ]
            )
        }
    }
}
