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


struct QuestionnaireEventDetailView: View {
    private let event: Event

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            List {
                DefaultTileHeader(event, alignment: .center)

                Section {
                    Text(event.task.instructions)
                } header: {
                    Text("Instructions")
                        .detailHeader()
                }

                if let about = event.task.about {
                    Section {
                        Text(LocalizedStringResource(about))
                    } header: {
                        Text("About")
                            .detailHeader()
                    }
                }
            }
                .navigationTitle("More Information")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button("Close") {
                        dismiss()
                    }
                }
        }
    }

    init(_ event: Event) {
        self.event = event
    }
}


extension Text {
    func detailHeader() -> some View {
        self
            .font(.title3)
            .fontWeight(.bold)
            .textCase(.none)
            .foregroundStyle(.primary)
    }
}


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
                    // TODO: reusable list!
                    List {
                        // TODO: today and tomorrow headings!?
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
                            // TODO: snapshot tests with different alignments + info button + with/without category
                            Section {
                                // TODO: completed doesn't work!
                                InstructionsTile(event) {
                                    QuestionnaireEventDetailView(event)
                                } action: {
                                    event.complete() // TODO: complete with keys?

                                    print("Outcome is now \(event.outcome)")
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
