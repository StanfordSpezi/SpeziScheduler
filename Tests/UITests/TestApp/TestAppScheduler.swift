//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziScheduler
import SpeziViews
import SwiftUI


@MainActor
@Observable
final class SchedulerModel {
    var viewState: ViewState = .idle

    nonisolated init() {}
}

struct TaskCategoryAppearances: ViewModifier {
    nonisolated init() {}

    func body(content: Content) -> some View {
        content
            .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))
    }
}


final class TestAppScheduler: Module {
    @Dependency(Scheduler.self)
    private var scheduler

    @Model private var model = SchedulerModel()
    @Modifier private var modifier = TaskCategoryAppearances()

    init() {}


    func configure() {
        do {
            try scheduler.createOrUpdateTask(
                id: "test-task",
                title: "Social Support Questionnaire",
                instructions: "Please fill out the Social Support Questionnaire every day.",
                category: .questionnaire,
                schedule: .daily(hour: 16, minute: 0, startingAt: .today),
                effectiveFrom: .today
            ) { context in
                context.about = """
                                The Social Support Questionnaire (SSQ) measures the availability and satisfaction of a person’s social support. \
                                It helps assess the strength of social networks, which are crucial for mental health, stress reduction, \
                                and overall well-being.
                                """
            }
        } catch {
            model.viewState = .error(AnyLocalizedError(
                error: error,
                defaultErrorDescription: "Failed to configure or update tasks."
            ))
        }
    }
}
