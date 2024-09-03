//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


public struct InstructionsTile: View {
    private let event: ILEvent

    public var body: some View {
        if event.completed {
            CompletedTile {
                Text(event.task.title)
                    .font(.headline)
            } description: {
                // TODO: completed description?
                Text(event.task.instructions)
                    .font(.callout)
            }
        } else {
            SimpleTile {
                TileHeader(event)
            } footer: {
                Text(event.task.instructions)
                    .font(.callout)
            } action: {
                // TODO: show sheet?
            } actionLabel: {
                Text("Start Questionnaire") // TODO: where to retrieve that from?
            }
        }
    }

    public init(_ event: ILEvent) {
        self.event = event
    }
}


#if DEBUG
#Preview {
    let task = ILTask(
        id: "example-task",
        title: "Social Support Questionnaire",
        instructions: "Please fill out the Social Support Questionnaire every day.",
        schedule: .daily(hour: 17, minute: 30, startingAt: .today)
    )
    let occurrence = task.schedule.occurrences(inDay: .today).first!
    let event = ILEvent(task: task, occurrence: occurrence, outcome: nil)
    return InstructionsTile(event)
        .padding()
}
#endif
