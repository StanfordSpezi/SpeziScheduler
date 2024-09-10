//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziViews
import SpeziScheduler
import SwiftUI


@MainActor
@Observable
final class SchedulerModel {
    var viewState: ViewState = .idle

    nonisolated init() {}
}


final class TestAppScheduler: Module {
    @Dependency(Scheduler.self)
    private var scheduler

    @Model private var model = SchedulerModel()

    init() {}


    func configure() {
        do {
            try scheduler.createOrUpdateTask(
                id: "test-task",
                title: "Social Support Questionnaire",
                instructions: "Please fill out the Social Support Questionnaire every day.",
                schedule: .daily(hour: 16, minute: 0, startingAt: .today),
                effectiveFrom: .today
            )
        } catch {
            model.viewState = .error(AnyLocalizedError(
                error: error,
                defaultErrorDescription: "Failed to configure or update tasks."
            ))
        }
    }
}
