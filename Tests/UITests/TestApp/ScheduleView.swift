//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziScheduler
import SpeziSchedulerUI
import SpeziViews
import SwiftUI


struct ScheduleView: View {
    @EventQuery(in: Date.today..<Date.tomorrow)
    private var events

    @Environment(SchedulerModel.self)
    private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            EventScheduleList { event in
                InstructionsTile(event) {
                    QuestionnaireEventDetailView(event)
                } action: {
                    event.complete()
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
