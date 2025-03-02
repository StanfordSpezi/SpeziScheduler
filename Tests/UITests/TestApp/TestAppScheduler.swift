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


enum TaskIdentifier {
    static let socialSupportQuestionnaire = "test-task"
    static let testMeasurement = "test-measurement"
    static let testMedication = "test-medication"
    static let enterLabResults = "enter-lab-results"
}


final class TestAppScheduler: Module {
    @Application(\.logger)
    private var logger

    @Dependency(Scheduler.self)
    private var scheduler

    @Model private var model = SchedulerModel()

    init() {}


    func configure() { // swiftlint:disable:this function_body_length
        do {
            try scheduler.createOrUpdateTask(
                id: TaskIdentifier.socialSupportQuestionnaire,
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

            let now = Date.now
            let time = notificationTestTime(for: now, adding: .seconds(40))

            try scheduler.createOrUpdateTask(
                id: TaskIdentifier.testMeasurement,
                title: "Weight Measurement",
                instructions: "Take a weight measurement every day.",
                category: .measurement,
                schedule: .daily(hour: time.hour, minute: time.minute, second: time.second, startingAt: now),
                scheduleNotifications: true
            ) { context in
                context.about = "Take a measurement with your nearby bluetooth scale while the app is running in foreground."
            }

            try scheduler.createOrUpdateTask(
                id: TaskIdentifier.testMedication,
                title: "Medication",
                instructions: "Take your medication",
                category: .medication,
                schedule: .daily(hour: time.hour, minute: time.minute, second: time.second, startingAt: .nextWeek),
                scheduleNotifications: true // a daily task that starts next week requires event-level notification scheduling
            )
            
            try scheduler.createOrUpdateTask(
                id: TaskIdentifier.enterLabResults,
                title: "Enter Lab Results",
                instructions: "You should enter Lab Results into the app at least once every 7 days!",
                category: .labResults,
                schedule: .daily(hour: time.hour, minute: time.minute, second: time.second, startingAt: now),
                completionPolicy: .sameDay,
                scheduleNotifications: true,
                shadowedOutcomesHandling: .delete
            )
        } catch {
            logger.error("Failed to scheduled TestApp tasks: \(error)")
            model.viewState = .error(AnyLocalizedError(
                error: error,
                defaultErrorDescription: "Failed to configure or update tasks."
            ))
        }
    }

    private func notificationTestTime(for date: Date, adding duration: Duration) -> NotificationTime {
        let now = date.addingTimeInterval(Double(duration.components.seconds))
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        guard let hour = components.hour,
              let minute = components.minute,
              let second = components.second else {
            preconditionFailure("Consistency error")
        }
        return NotificationTime(hour: hour, minute: minute, second: second)
    }
}


extension Task.Category {
    static let labResults = Self.custom("lab-results")
}
