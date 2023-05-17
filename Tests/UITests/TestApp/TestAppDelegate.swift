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
                            dateComponents: .init(nanosecond: 500_000_000), // every 0.5 seconds
                            end: .numberOfEvents(1)
                        ),
                        context: "Original Task!"
                    )
                ]
            )
        }
    }
}
