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
            Group {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No Events",
                        systemImage: "pencil.and.list.clipboard",
                        description: Text("Currently there are no upcoming events.")
                    )
                } else {
                    // TODO: reusable list!
                    // TODO: today and tomorrow headings!?
                    List {
                        Section {
                            Text("Today")
                                .foregroundStyle(.secondary)
                                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowBackground(Color.clear)
                                .font(.title)
                                .fontDesign(.rounded)
                                .fontWeight(.bold)
                        }


                        ForEach(events) { event in
                            Section {
                                InstructionsTile(event) {
                                    QuestionnaireEventDetailView(event)
                                } action: {
                                    event.complete()
                                }
                            }
                        }
                    }
                        .listSectionSpacing(.compact)
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
