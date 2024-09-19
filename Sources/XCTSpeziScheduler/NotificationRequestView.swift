//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI
import UserNotifications


/// Present the details of a notification request.
public struct NotificationRequestView: View {
    private let request: UNNotificationRequest

    public var body: some View {
        List {
            Section("Content") {
                LabeledContent("Title", value: request.content.title)
                if !request.content.subtitle.isEmpty {
                    LabeledContent("Subtitle", value: request.content.subtitle)
                }
                LabeledContent("Body", value: request.content.body) // TODO: too long?

                if !request.content.categoryIdentifier.isEmpty {
                    LabeledContent("Category", value: request.content.categoryIdentifier)
                }

                if !request.content.threadIdentifier.isEmpty {
                    LabeledContent("Thread", value: request.content.threadIdentifier)
                }
            }

            Section("Delivery") {
                LabeledContent("Sound", value: request.content.sound != nil ? "Yes" : "No")
                // TODO: is num raw value, make description!
                LabeledContent("Interruption", value: request.content.interruptionLevel.rawValue.description)
            }

            if let trigger = request.trigger {
                Section("Trigger") {
                    LabeledContent("Type", value: trigger.type)
                    if let nextDate = trigger.nextDate() {
                        LabeledContent("Next Trigger") {
                            Text("in \(Text(.currentDate, format: SystemFormatStyle.DateOffset(to: nextDate, sign: .never)))")
                        }
                    }
                }
            }

            Section {
                LabeledContent("Identifier", value: request.identifier)
            }
        }
        .navigationTitle(request.content.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    /// Create a new notification request details view.
    /// - Parameter request: The notification request.
    public init(_ request: UNNotificationRequest) {
        self.request = request
    }
}
