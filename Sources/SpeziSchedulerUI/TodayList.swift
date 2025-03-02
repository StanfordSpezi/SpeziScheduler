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
@available(*, deprecated, renamed: "EventScheduleList", message: "Use EventScheduleList instead, which by default displays today's events.")
public struct TodayList<Tile: View>: View {
    private let makeEventTile: @MainActor (Event) -> Tile
    
    public var body: some View {
        EventScheduleList(content: makeEventTile)
    }
    
    /// Create a new today list.
    /// - Parameter content: A closure that is called to display each event occurring today.
    public init(@ViewBuilder content: @MainActor @escaping (Event) -> Tile) {
        self.makeEventTile = content
    }
}
