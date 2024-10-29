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


/// An overview of all task for a specific day.
///
/// The view renders all task occurring on a specified date in a list view.
///
/// ```swift
/// EventScheduleList { event in
///     InstructionsTile(event) {
///         event.complete()
///     } more: {
///         QuestionnaireEventDetailView(event)
///     }
/// }
///     .navigationTitle("Schedule")
/// ```
public struct EventScheduleList<Tile: View>: View {
    private let date: Date
    private let endOfDayExclusive: Date

    @EventQuery(in: Date.today..<Date.tomorrow)
    private var events

    @ManagedViewUpdate private var viewUpdate

    private var eventTile: (Event) -> Tile

    private var hasValidData: Bool {
        $events.fetchError == nil && !events.isEmpty
    }

    private var listTitle: Text {
        if Calendar.current.isDateInToday(date) {
            Text("Today", bundle: .module)
        } else if Calendar.current.isDateInTomorrow(date) {
            Text("Tomorrow", bundle: .module)
        } else if Calendar.current.isDateInYesterday(date) {
            Text("Yesterday", bundle: .module)
        } else {
            Text(date, format: Date.FormatStyle(date: .numeric))
        }
    }

    private var unavailableTitle: Text {
        if Calendar.current.isDateInToday(date) {
            Text("No Events Today", bundle: .module)
        } else if Calendar.current.isDateInTomorrow(date) {
            Text("No Events Tomorrow", bundle: .module)
        } else if Calendar.current.isDateInYesterday(date) {
            Text("No Events Yesterday", bundle: .module)
        } else {
            Text("No Events", bundle: .module)
        }
    }

    private var unavailableDescription: Text {
        if Calendar.current.isDateInToday(date) {
            Text("There are no events scheduled for today.", bundle: .module)
        } else if Calendar.current.isDateInTomorrow(date) {
            Text("There are no events scheduled for tomorrow.", bundle: .module)
        } else if Calendar.current.isDateInYesterday(date) {
            Text("There are no events scheduled for yesterday.", bundle: .module)
        } else {
            Text("There are no events scheduled that date.", bundle: .module)
        }
    }

    public var body: some View {
        List {
            if hasValidData {
                Section {
                    listTitle
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
        }
#if !os(macOS)
            .listSectionSpacing(.compact)
#endif
            .overlay {
                contentUnavailableOverlay
            }
    }

    @ViewBuilder private var contentUnavailableOverlay: some View {
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
                    unavailableTitle
                } icon: {
                    Image(systemName: "pencil.and.list.clipboard")
                        .accessibilityHidden(true)
                }
            } description: {
                unavailableDescription
            }
        }
    }

    
    /// Create a new event schedule list.
    /// - Parameters:
    ///   - date: The date for which the event schedule is display.
    ///   - content: A closure that is called to display each event occurring today.
    public init(date: Date = .today, content: @escaping (Event) -> Tile) {
        self.date = Calendar.current.startOfDay(for: date)
        self.eventTile = content

        guard let endOfDayExclusive = Calendar.current.date(byAdding: .day, value: 1, to: date) else {
            preconditionFailure("Failed to construct endOfDayExclusive from base \(date).")
        }
        self.endOfDayExclusive = endOfDayExclusive
    }
}
