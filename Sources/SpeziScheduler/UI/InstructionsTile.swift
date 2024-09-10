//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


public struct InstructionsTile<Header: View, Info: View>: View {
    private let alignment: HorizontalAlignment
    private let event: Event
    private let header: Header
    private let actionClosure: (() -> Void)?
    private let moreInformation: Info
    private let customActionLabel: Text?

    @Environment(Scheduler.self)
    private var scheduler

    @State private var presentingMoreInformation: Bool = false

    private var action: TileAction<some View>? {
        if let actionClosure {
            TileAction(action: actionClosure, label: actionLabel)
        } else {
            nil
        }
    }

    private var actionLabel: some View {
        if let customActionLabel {
            customActionLabel
        } else if let category = event.task.category {
            Text("Complete \(category.label)", bundle: .module, comment: "category label")
        } else {
            Text("Complete", bundle: .module)
        }
    }

    private var moreInfoButton: some View {
        Button {
            presentingMoreInformation = true
        } label: {
            Label {
                Text("More Information", bundle: .module)
            } icon: {
                Image(systemName: "info.circle")
                    .accessibilityHidden(true)
            }
        }
            .buttonStyle(.borderless)
    }

    public var body: some View {
        if event.completed {
            CompletedTile {
                Text(event.task.title)
                    .font(.headline)
            } description: {
                Text(event.task.instructions)
                    .font(.callout)
            }
        } else {
            SimpleTile(alignment: alignment, action: action) {
                if Info.self != EmptyView.self {
                    let layout = alignment == .center
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                        : AnyLayout(HStackLayout(alignment: .center))

                    layout {
                        header

                        if alignment == .center {
                            moreInfoButton
                                .labelStyle(.titleAndIcon)
                                .font(.footnote)
                        } else {
                            moreInfoButton
                                .labelStyle(.iconOnly)
                                .font(.title3)
                        }
                    }
                } else {
                    header
                }
            } footer: {
                Text(event.task.instructions)
                    .font(.callout)
            }
                .sheet(isPresented: $presentingMoreInformation) {
                    moreInformation
                }
        }
    }

    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading,
        actionLabel customActionLabel: Text? = nil,
        @ViewBuilder header: () -> Header,
        @ViewBuilder more: () -> Info = { EmptyView() },
        perform action: @escaping () -> Void
    ) {
        self.alignment = alignment
        self.event = event
        self.header = header()
        self.moreInformation = more()
        self.actionClosure = action
        self.customActionLabel = customActionLabel
    }

    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading,
        @ViewBuilder header: () -> Header,
        @ViewBuilder more: () -> Info = { EmptyView() }
    ) {
        self.alignment = alignment
        self.event = event
        self.header = header()
        self.moreInformation = more()
        self.actionClosure = nil
        self.customActionLabel = nil
    }

    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading,
        actionLabel customActionLabel: Text? = nil,
        @ViewBuilder more: () -> Info = { EmptyView() },
        perform action: @escaping () -> Void
    ) where Header == DefaultTileHeader {
        self.init(
            event,
            alignment: alignment,
            actionLabel: customActionLabel,
            header: { DefaultTileHeader(event, alignment: alignment) },
            more: more,
            perform: action
        )
    }

    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading,
        @ViewBuilder more: () -> Info = { EmptyView() }
    ) where Header == DefaultTileHeader {
        self.init(event, alignment: alignment, header: { DefaultTileHeader(event, alignment: alignment) }, more: more)
    }
}


#if DEBUG
#Preview(traits: .schedulerSampleData) {
    @EventQuery(in: .sampleEventRange)
    @Previewable var events

    if let error = $events.fetchError {
        Text("Error Occurrence: \(error)")
    } else if let first = events.first {
        List {
            InstructionsTile(first) {
                first.complete()
            }
        }
    } else {
        ProgressView()
    }
}

#Preview(traits: .schedulerSampleData) {
    @EventQuery(in: .sampleEventRange)
    @Previewable var events

    if let error = $events.fetchError {
        Text("Error Occurrence: \(error)")
    } else if let first = events.first {
        List {
            InstructionsTile(first, alignment: .center) {
                Text("More information about the task!")
            } perform: {
                first.complete()
            }
        }
    } else {
        ProgressView()
    }
}
#endif
