//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Combine
@_spi(TestingSupport)
import SpeziScheduler
import SwiftUI


@Observable
class UIUpdate { // TODO: move to SpeziViews!
    @MainActor private var dateTimer: Timer? {
        willSet {
            dateTimer?.invalidate()
        }
    }

    nonisolated init() {}

    @MainActor
    func scheduleUpdate(at date: Date) {
        @MainActor
        struct WeakSendingSelf: Sendable { // assumeIsolated requires a @Sendable closure, so we need to pass self via a Sendable type
            weak var value: UIUpdate?

            init(_ value: UIUpdate) {
                self.value = value
            }
        }

        let sendingSelf = WeakSendingSelf(self)

        let timer = Timer(fire: date, interval: 0, repeats: false) { [sendingSelf] _ in
            MainActor.assumeIsolated { [sendingSelf] in
                sendingSelf.value?.dateTimer = nil // triggers observable mutation
            }
        }
        RunLoop.main.add(timer, forMode: .common)

        self.dateTimer = timer // triggers observable access
    }

    deinit {
        _dateTimer?.invalidate()
    }
}


public struct InstructionsTile<Header: View, Info: View>: View {
    private let alignment: HorizontalAlignment
    private let event: Event
    private let header: Header
    private let actionClosure: (() -> Void)?
    private let moreInformation: Info
    private let customActionLabel: Text?

    @Environment(Scheduler.self)
    private var scheduler
    @Environment(\.taskCategoryAppearances)
    private var taskCategoryAppearances

    @State private var presentingMoreInformation: Bool = false
    @State private var actionDisabledUpdate = UIUpdate()

    private var action: TileAction<some View>? {
        if let actionClosure {
            TileAction(action: actionClosure, label: actionLabel, disabled: actionDisabled)
        } else {
            nil
        }
    }

    private var actionLabel: some View {
        if let customActionLabel {
            customActionLabel
        } else if let category = event.task.category,
                  let appearance = taskCategoryAppearances[category] {
            Text("Complete \(Text(appearance.label))", bundle: .module, comment: "category label")
        } else {
            Text("Complete", bundle: .module)
        }
    }

    private var actionDisabled: Bool {
        let policy = event.task.completionPolicy

        let now = Date.now
        let disabled = policy.isAllowedToComplete(event: event, now: now)
        if disabled {
            if let uiUpdate = policy.dateOnceCompletionIsAllowed(for: event, now: now) {
                actionDisabledUpdate.scheduleUpdate(at: uiUpdate)
            }
        } else {
            if let uiUpdate = policy.dateOnceCompletionBecomesDisallowed(for: event, now: now) {
                actionDisabledUpdate.scheduleUpdate(at: uiUpdate)
            }
        }

        return false
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
            .accessibilityLabel("More Information")
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
                .accessibilityAction(named: Text("More Information")) {
                    presentingMoreInformation = true
                }
        }
    }
    
    /// Create a new instructions tile with an action button, custom header view and optional details view.
    /// - Parameters:
    ///   - event: The event instance.
    ///   - alignment: The horizontal alignment of the tile.
    ///   - customActionLabel: A custom label for the action button. Otherwise, a generic default value will be used.
    ///   - header: A custom header that is shown on the top of the tile. You can use the ``TileHeader`` view as a basis for your implementation.
    ///   - more: An optional view that is presented as a sheet if the user presses the "more information" button. The view can be used to provide additional explanation or instructions
    ///         for a task.
    ///   - action: The closure that is executed if the action button is pressed.
    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading,
        actionLabel customActionLabel: Text? = nil,
        @ViewBuilder header: () -> Header,
        @ViewBuilder more: () -> Info = { EmptyView() },
        action: @escaping () -> Void
    ) {
        self.alignment = alignment
        self.event = event
        self.header = header()
        self.moreInformation = more()
        self.actionClosure = action
        self.customActionLabel = customActionLabel
    }
    
    /// Create a new instructions tile with a custom header and an optional details view.
    /// - Parameters:
    ///   - event: The event instance.
    ///   - alignment: The horizontal alignment of the tile.
    ///   - header: A custom header that is shown on the top of the tile. You can use the ``TileHeader`` view as a basis for your implementation.
    ///   - more: An optional view that is presented as a sheet if the user presses the "more information" button. The view can be used to provide additional explanation or instructions
    ///         for a task.
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
    
    /// Create a new instructions tile with an action button and optional details view.
    ///
    /// This initializers uses the ``DefaultTileHeader``.
    /// - Parameters:
    ///   - event: The event instance.
    ///   - alignment: The horizontal alignment of the tile.
    ///   - customActionLabel: A custom label for the action button. Otherwise, a generic default value will be used.
    ///   - more: An optional view that is presented as a sheet if the user presses the "more information" button. The view can be used to provide additional explanation or instructions
    ///         for a task.
    ///   - action: The closure that is executed if the action button is pressed.
    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading,
        actionLabel customActionLabel: Text? = nil,
        @ViewBuilder more: () -> Info = { EmptyView() },
        action: @escaping () -> Void
    ) where Header == DefaultTileHeader {
        self.init(
            event,
            alignment: alignment,
            actionLabel: customActionLabel,
            header: { DefaultTileHeader(event, alignment: alignment) },
            more: more,
            action: action
        )
    }
    
    /// Create a new instructions tile with an optional details view.
    ///
    /// This initializers uses the ``DefaultTileHeader``.
    /// - Parameters:
    ///   - event: The event instance.
    ///   - alignment: The horizontal alignment of the tile.
    ///   - more: An optional view that is presented as a sheet if the user presses the "more information" button. The view can be used to provide additional explanation or instructions
    ///         for a task.
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
            } action: {
                first.complete()
            }
        }
    } else {
        ProgressView()
    }
}
#endif
