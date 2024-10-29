//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


import SpeziScheduler
import SpeziViews
import SwiftUI


/// An overview of all task for today.
///
/// The view renders all task occurring today in a list view.
///
/// ```swift
/// TodayList { event in
///     InstructionsTile(event) {
///         QuestionnaireEventDetailView(event)
///     } action: {
///         event.complete()
///     }
/// }
///     .navigationTitle("Schedule")
/// ```
public struct TodayList<Tile: View>: View {
    @EventQuery(in: Date.today..<Date.tomorrow)
    private var events

    @ManagedViewUpdate private var viewUpdate

    private var eventTile: (Event) -> Tile

    public var body: some View {
        if let fetchError = $events.fetchError {
            ContentUnavailableView {
                Label {
                    Text("Failed to fetch Events", bundle: .module)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .accessibilityHidden(true)
                }
                    .symbolRenderingMode(.multicolor)
            } description: {
                if let localizedError = fetchError as? LocalizedError,
                   let reason = localizedError.failureReason {
                    Text(reason)
                } else {
                    Text("An unknown error occurred.")
                }
            } actions: {
                Button {
                    viewUpdate.refresh()
                } label: {
                    Label {
                        Text("Retry", bundle: .module)
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                            .accessibilityHidden(true)
                    }
                }
            }
        } else if events.isEmpty {
            ContentUnavailableView {
                Label {
                    Text("No Events Today", bundle: .module)
                } icon: {
                    Image(systemName: "pencil.and.list.clipboard")
                        .accessibilityHidden(true)
                }
            } description: {
                Text("There are no events scheduled for today.")
            }
        } else {
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
                        eventTile(event)
                    }
                }
            }
#if !os(macOS)
                .listSectionSpacing(.compact)
#endif
        }
    }
    
    /// Create a new today list.
    /// - Parameter content: A closure that is called to display each event occurring today.
    public init(content: @escaping (Event) -> Tile) {
        self.eventTile = content
    }
}
