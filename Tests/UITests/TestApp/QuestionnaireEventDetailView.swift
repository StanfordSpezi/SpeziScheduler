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
