//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziViews
import SwiftUI


struct TileHeader: View {
    private static let iconRealignSize: DynamicTypeSize = .accessibility3

    private let event: ILEvent

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass // for iPad or landscape we want to stay horizontal

    @State private var subheadlineLayout: DynamicLayout?

    private var iconGloballyPlaced: Bool {
        horizontalSizeClass == .regular || dynamicTypeSize < Self.iconRealignSize
    }

    var body: some View {
        HStack {
            if iconGloballyPlaced {
                clipboard
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if !iconGloballyPlaced {
                        clipboard
                    }
                    Text(event.task.title)
                        .font(.headline)
                }
                subheadline
            }
        }
    }

    @ViewBuilder private var clipboard: some View { // TODO: customize the icon based on the event
        Image(systemName: "list.bullet.clipboard")
            .foregroundColor(.accentColor)
            .font(.custom("Screening Task Icon", size: 30, relativeTo: .headline))
            .accessibilityHidden(true)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    @ViewBuilder private var subheadline: some View {
        DynamicHStack(realignAfter: .xxxLarge) {
            Text("Questionnaire") // TODO: label?

            if subheadlineLayout == .horizontal {
                Spacer()
            }

            Text(event.occurrence.start, style: .time) // TODO: end date?
            // TODO: Text("\(task.expectedCompletionMinutes) min", comment: "Expected task completion in minutes.")
            //    .accessibilityLabel("takes \(task.expectedCompletionMinutesSpoken) min")
        }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .accessibilityElement(children: .combine)
            .onPreferenceChange(DynamicLayout.self) { layout in
                subheadlineLayout = layout
            }
    }


    init(_ event: ILEvent) {
        self.event = event
    }
}


#if DEBUG
#Preview(traits: .schedulerSampleData) {
    @EventQuery(in: .sampleEventRange)
    @Previewable var events

    List {
        if let event = events.first {
            TileHeader(event)
        } else {
            Text(verbatim: "Missing event")
        }
    }
}
#endif
