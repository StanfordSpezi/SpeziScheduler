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
/// Example: display all tasks scheduled for today:
///
/// ```swift
/// EventScheduleList { event in
///     InstructionsTile(event) {
///         event.complete()
///     } more: {
///         QuestionnaireEventDetailView(event)
///     }
/// }
/// .navigationTitle("Schedule")
/// ```
public struct EventScheduleList<Tile: View>: View {
    @Environment(\.calendar)
    private var cal
    
    private let makeEventTile: @MainActor (Event) -> Tile
    
    @EventQuery private var events: [Event]
    @ManagedViewUpdate private var viewUpdate
    
    private var range: Range<Date> {
        $events.range
    }
    
    private var hasValidData: Bool {
        $events.fetchError == nil && !events.isEmpty
    }

    private var listTitle: Text {
        switch range {
        case cal.rangeOfDay(for: .now):
            Text("Today", bundle: .module)
        case cal.rangeOfDay(for: cal.startOfNextDay(for: .now)):
            Text("Tomorrow", bundle: .module)
        case cal.rangeOfDay(for: cal.startOfPrevDay(for: .now)):
            Text("Yesterday", bundle: .module)
        default:
            Text(range.lowerBound, format: Date.FormatStyle(date: .numeric))
        }
    }

    private var unavailableTitle: Text {
        switch range {
        case cal.rangeOfDay(for: .now):
            Text("No Events Today", bundle: .module)
        case cal.rangeOfDay(for: cal.startOfNextDay(for: .now)):
            Text("No Events Tomorrow", bundle: .module)
        case cal.rangeOfDay(for: cal.startOfPrevDay(for: .now)):
            Text("No Events Yesterday", bundle: .module)
        default:
            Text("No Events", bundle: .module)
        }
    }

    private var unavailableDescription: Text {
        switch range {
        case cal.rangeOfDay(for: .now):
            Text("There are no events scheduled for today.", bundle: .module)
        case cal.rangeOfDay(for: cal.startOfNextDay(for: .now)):
            Text("There are no events scheduled for tomorrow.", bundle: .module)
        case cal.rangeOfDay(for: cal.startOfPrevDay(for: .now)):
            Text("There are no events scheduled for yesterday.", bundle: .module)
        default:
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
                        makeEventTile(event)
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
                if let localizedError = fetchError as? any LocalizedError,
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
    ///   - date: The date for which events should be displayed. Defaults to today.
    ///   - makeEventTile: A closure that constructs the views for the individual `Event`s.
    public init(date: Date = .today, @ViewBuilder content makeEventTile: @MainActor @escaping (Event) -> Tile) {
        self.init(for: Calendar.current.rangeOfDay(for: date), content: makeEventTile)
    }
    
    
    /// Create a new event schedule list.
    ///
    /// - parameter range: The (exclusive) range for which events should be displayed.
    /// - parameter makeEventTile: A closure that constructs the views for the individual `Event`s.
    public init(for range: Range<Date>, @ViewBuilder content makeEventTile: @MainActor @escaping (Event) -> Tile) {
        self._events = .init(in: range)
        self.makeEventTile = makeEventTile
    }
}
