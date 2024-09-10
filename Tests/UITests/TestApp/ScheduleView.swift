//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziScheduler
import SpeziViews
import SwiftUI


struct ScheduleView: View {
    // TODO: show today vs tomorrow?
    @EventQuery(in: Date.today..<Date.tomorrow)
    private var events

    @Environment(SchedulerModel.self)
    private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No Events",
                        systemImage: "pencil.and.list.clipboard",
                        description: Text("Currently there are no upcoming events.")
                    )
                } else {
                    // TODO: today and tomorrow headings!?
                    List(events) { event in
                        InstructionsTile(event)
                    }
                }
            }
                .navigationTitle("Schedule")
                .viewStateAlert(state: $model.viewState)
        }
    }
}


#if DEBUG
#Preview {
    ScheduleView()
        .environment(SchedulerModel())
}
#endif
