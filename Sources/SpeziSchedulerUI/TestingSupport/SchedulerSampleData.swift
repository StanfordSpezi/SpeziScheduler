//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
@_spi(Internal)
@_spi(TestingSupport)
import SpeziScheduler
import SwiftData
import SwiftUI


@_spi(TestingSupport)
public struct SchedulerSampleData: PreviewModifier {
    public init() {}

    public static func makeTestTask() -> Task {
        Task(
            id: "example-task",
            title: "Social Support Questionnaire",
            instructions: "Please fill out the Social Support Questionnaire every day.",
            category: .questionnaire,
            schedule: .daily(hour: 17, minute: 0, startingAt: .today),
            completionPolicy: .sameDay,
            scheduleNotifications: false,
            notificationThread: .task,
            tags: [],
            effectiveFrom: .today // make sure test task always starts from the start of today
        )
    }

    public static func makeTestEvent() -> Event {
        let task = makeTestTask()

        guard let occurrence = task.schedule.occurrences(inDay: .today).first else {
            preconditionFailure("Failed to retrieve occurrences for today.")
        }

        return Event(task: task, occurrence: occurrence, outcome: .mocked)
    }

    public static func makeSharedContext() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Task.self, Outcome.self, configurations: configuration)

        let task = makeTestTask()

        container.mainContext.insert(task)
        try container.mainContext.save()

        return container
    }

    public func body(content: Content, context: ModelContainer) -> some View {
        content
            .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.bullet.clipboard"))
            .previewWith {
                Scheduler(persistence: .testingContainer(context))
            }
    }
}


extension PreviewTrait where T == Preview.ViewTraits {
    /// A preview modifier that provide sample data to the scheduler.
    ///
    /// - Note: This preview modifier uses Spezi's [`previewWith(simulateLifecycle:_:)`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/swiftui/view/previewwith(simulatelifecycle:_:))
    ///     modifier under the hood. Therefore, it is not possible to use this preview modifier if you already
    ///     using your own `previewWith(simulateLifecycle:_:)` modifier in your view hierarchy of the preview.
    @_spi(TestingSupport)
    public static var schedulerSampleData: PreviewTrait<T> {
        .modifier(SchedulerSampleData())
    }
}


extension Range where Bound == Date {
    /// A date range used with scheduler sample events.
    @_spi(TestingSupport)
    public static var sampleEventRange: Range<Date> {
        Date.today..<Date.tomorrow
    }
}
