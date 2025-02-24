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

enum DateSelection: Hashable {
    case today
    case tomorrow
    case date
}


struct ScheduleView: View {
    @EventQuery(in: Date.today..<Date.tomorrow)
    private var events

    @Environment(SchedulerModel.self)
    private var model

    @State private var alignment: HorizontalAlignment = .leading
    @State private var hidden = false // hide for screenshots
    @State private var dateSelection: DateSelection = .today
    @State private var date = Date()

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            EventScheduleList(date: date) { event in
                if event.task.id == TaskIdentifier.socialSupportQuestionnaire {
                    InstructionsTile(event, alignment: alignment) {
                        try? event.complete()
                    } more: {
                        EventDetailView(event)
                    }
                } else {
                    InstructionsTile(event, more: {
                        EventDetailView(event)
                    })
                }
            }
                .navigationTitle("Schedule")
                .viewStateAlert(state: $model.viewState)
                .toolbar {
                    toolbar
                }
                .onChange(of: dateSelection, initial: true) {
                    switch dateSelection {
                    case .today:
                        date = .today
                    case .tomorrow:
                        date = .tomorrow
                    case .date:
                        guard let date = Calendar.current.date(byAdding: .day, value: 3, to: .now) else {
                            preconditionFailure("Failed to calulcate date")
                        }
                        self.date = date
                    }
                }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .secondaryAction) {
            if !hidden {
                Picker("Alignment", selection: $alignment) {
                    Text("Leading").tag(HorizontalAlignment.leading)
                    Text("Center").tag(HorizontalAlignment.center)
                    Text("Trailing").tag(HorizontalAlignment.trailing)
                }

                Picker("Date", selection: $dateSelection) {
                    Text("Today").tag(DateSelection.today)
                    Text("Tomorrow").tag(DateSelection.tomorrow)
                    Text("Date").tag(DateSelection.date)
                }

                Button("Hide Content", action: hide)
            }
        }
    }

    private func hide() {
        hidden = true
        _Concurrency.Task {
            try? await _Concurrency.Task.sleep(for: .seconds(5))
            hidden = false
        }
    }
}


extension HorizontalAlignment: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
}


#if DEBUG
#Preview {
    ScheduleView()
        .environment(SchedulerModel())
}
#endif
