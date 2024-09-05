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
                // TODO: what is the action, show a sheet?
            } actionLabel: {
                Text("Start Questionnaire") // TODO: how to retrieve that?
            }
        }
    }

    public init(_ event: ILEvent) {
        self.event = event
    }
}


#if DEBUG
#Preview(traits: .schedulerSampleData) {
    @EventQuery(in: Date.now..<Calendar.current.date(byAdding: .day, value: 1, to: .tomorrow)!) @Previewable var events

    if let error = $events.fetchError {
        Text("Error Occurrence: \(error)")
    } else if let first = events.first {
        InstructionsTile(first)
            .padding()
    } else {
        ProgressView()
    }
}
#endif
