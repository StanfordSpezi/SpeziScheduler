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


/// A pre-styled button that can be used to complete an event.
///
///
public struct EventActionButton: View {
    private let event: Event
    private let customLabel: Text?
    private let action: () -> Void

    @Environment(\.taskCategoryAppearances)
    private var taskCategoryAppearances

    @ManagedViewUpdate private var actionUpdate


    private var isEventCompletionAllowed: Bool {
        let policy = event.task.completionPolicy
        let now = Date.now
        let allowed = policy.isAllowedToComplete(event: event, now: now)
        if allowed {
            if let dateWhenDisallowed = policy.dateOnceCompletionBecomesDisallowed(for: event, now: now), dateWhenDisallowed != .distantFuture {
                actionUpdate.schedule(at: dateWhenDisallowed)
            }
        } else {
            if let dateWhenAllowed = policy.dateOnceCompletionIsAllowed(for: event, now: now), dateWhenAllowed != .distantPast {
                actionUpdate.schedule(at: dateWhenAllowed)
            }
        }
        return allowed
    }

    private var actionLabel: Text {
        if let customLabel {
            customLabel
        } else if let category = event.task.category,
                  let appearance = taskCategoryAppearances[category] {
            Text("Complete \(Text(appearance.label))", bundle: .module, comment: "category label")
        } else {
            Text("Complete", bundle: .module)
        }
    }

    public var body: some View {
        Button(action: action) {
            actionLabel
                .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isEventCompletionAllowed)
    }

    init(event: Event, label: Text?, action: @escaping () -> Void) {
        self.event = event
        self.customLabel = label
        self.action = action
    }
    
    /// Create a new event action button with a default label.
    /// - Parameters:
    ///   - event: The event.
    ///   - action: The action to be called when the button is pressed.
    public init(event: Event, action: @escaping () -> Void) {
        self.init(event: event, label: nil, action: action)
    }
    
    /// Create a new action button with a custom localized label.
    /// - Parameters:
    ///   - event: The event.
    ///   - label: The label of the button.
    ///   - action: The action to be called when the button is pressed.
    public init(event: Event, _ label: LocalizedStringResource, action: @escaping () -> Void) {
        self.init(event: event, label: Text(label), action: action)
    }
    
    /// Create a new action button with a custom label view.
    /// - Parameters:
    ///   - event: The event.
    ///   - action: The action to be called when the button is pressed.
    ///   - label: The label of the button as a Text view.
    public init(event: Event, action: @escaping () -> Void, @ViewBuilder label: () -> Text) {
        self.init(event: event, label: label(), action: action)
    }
}
