//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziScheduler


typealias TestAppScheduler = Scheduler<String>


class TestAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration(standard: ExampleStandard()) {
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
