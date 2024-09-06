//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziScheduler
import SwiftUI


struct ScheduleView: View {
    // TODO: show today vs tomorrow?
    @EventQuery(in: Date.today..<Date.tomorrow)
    private var events

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No Events",
                        systemImage: "pencil.and.list.clipboard",
                        description: Text("Currently there are no upcoming events.")
                    )
                } else {
                    // TODO: today and tomorrow headings!
                    List(events) { event in
                        InstructionsTile(event)
                        // TODO: completing event is not really great!

                        /*
                        CompletedTile {
                            Text(event.task.title)
                                .font(.headline)
                        } description: {
                            // TODO: completed description?
                            Text(event.task.instructions)
                                .font(.callout)
                        }*/
                    }
                }
            }
                .navigationTitle("Schedule")
        }
    }
}


#if DEBUG
#Preview {
    ScheduleView()
}
#endif
