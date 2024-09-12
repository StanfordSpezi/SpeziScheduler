//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport)
import SpeziScheduler
import SpeziViews
import SwiftUI


public struct DefaultTileHeader: View {
    private let alignment: HorizontalAlignment
    private let event: Event

    @Environment(\.taskCategoryAppearances)
    private var taskCategoryAppearances

    public var body: some View {
        TileHeader(alignment: alignment) {
            if let category = event.task.category,
               let appearance = taskCategoryAppearances[category],
               let image = appearance.image?.image {
                image
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
                    .font(.custom("Task Icon", size: alignment == .center ? 40 : 30, relativeTo: .headline))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            } else {
                EmptyView()
            }
        } title: {
            Text(event.task.title)
        } subheadline: {
            if let category = event.task.category,
               let appearance = taskCategoryAppearances[category] {
                subheadline(with: appearance)
            } else {
                dateSubheadline()
            }
        }
    }


    public init(_ event: Event, alignment: HorizontalAlignment = .leading) {
        self.event = event
        self.alignment = alignment
    }


    @ViewBuilder
    private func subheadline(with appearance: Task.Category.Appearance) -> some View {
        if alignment == .center {
            VStack(alignment: .center) {
                Text(appearance.label)
                dateSubheadline()
            }
        } else {
            ViewThatFits(in: .horizontal) {
                if alignment == .trailing {
                    if let subheadline = dateSubheadline() {
                        Text("\(appearance.label), \(subheadline)", bundle: .module)
                    } else {
                        Text(appearance.label) // alignment is done by the parent VStack
                    }
                } else {
                    HStack {
                        Text(appearance.label)
                        Spacer()
                        dateSubheadline()
                    }
                        .accessibilityElement(children: .combine)
                        .lineLimit(1)
                }

                VStack(alignment: alignment) {
                    Text(appearance.label)
                    dateSubheadline()
                }
                    .accessibilityElement(children: .combine)
                    .lineLimit(1)
            }
        }
    }

    private func dateSubheadline() -> Text? {
        switch event.occurrence.schedule.duration {
        case .allDay:
            nil
        case .tillEndOfDay:
            Text(event.occurrence.start, style: .time)
        case .duration:
            Text(
                "\(Text(event.occurrence.start, style: .time)) to \(Text(event.occurrence.end, style: .time))",
                bundle: .module,
                comment: "start time till end time"
            )
        }
    }
}


#if DEBUG
#Preview(traits: .schedulerSampleData) {
    @EventQuery(in: .sampleEventRange)
    @Previewable var events

    List {
        if let event = events.first {
            DefaultTileHeader(event)
        } else {
            Text(verbatim: "Missing event")
        }
    }
}

#Preview(traits: .schedulerSampleData) {
    @EventQuery(in: .sampleEventRange)
    @Previewable var events

    List {
        if let event = events.first {
            DefaultTileHeader(event, alignment: .center)
        } else {
            Text(verbatim: "Missing event")
        }
    }
}

#Preview(traits: .schedulerSampleData) {
    @EventQuery(in: .sampleEventRange)
    @Previewable var events

    List {
        if let event = events.first {
            DefaultTileHeader(event, alignment: .trailing)
        } else {
            Text(verbatim: "Missing event")
        }
    }
}
#endif
