//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziViews
import SwiftUI
import UserNotifications


/// Present the details of a notification request.
public struct NotificationRequestView: View {
    private let request: UNNotificationRequest

    @ManagedViewUpdate private var viewUpdate

    public var body: some View {
        List {
            content

            delivery

            trigger

            Section {
                LabeledContent {
                    Text(request.identifier)
                } label: {
                    Text("Identifier", bundle: .module)
                }
                    .accessibilityElement(children: .combine)
            }
        }
            .navigationTitle(request.content.title)
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var content: some View {
        Section { // swiftlint:disable:this closure_body_length
            LabeledContent {
                Text(request.content.title)
            } label: {
                Text("Title", bundle: .module)
            }
                .accessibilityElement(children: .combine)

            if !request.content.subtitle.isEmpty {
                LabeledContent {
                    Text(request.content.subtitle)
                } label: {
                    Text("Subtitle", bundle: .module)
                }
                    .accessibilityElement(children: .combine)
            }

            LabeledContent {
                Text(request.content.body)
            } label: {
                Text("Body", bundle: .module)
            }
                .accessibilityElement(children: .combine)

            if !request.content.categoryIdentifier.isEmpty {
                LabeledContent {
                    Text(request.content.categoryIdentifier)
                } label: {
                    Text("Category", bundle: .module)
                }
                    .accessibilityElement(children: .combine)
            }

            if !request.content.threadIdentifier.isEmpty {
                LabeledContent {
                    Text(request.content.threadIdentifier)
                } label: {
                    Text("Thread", bundle: .module)
                }
                    .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Content", bundle: .module)
        }
    }

    @ViewBuilder private var delivery: some View {
        Section {
            LabeledContent {
                Text(request.content.sound != nil ? "Yes" : "No", bundle: .module)
            } label: {
                Text("Sound", bundle: .module)
            }
                .accessibilityElement(children: .combine)

            LabeledContent {
                Text(request.content.interruptionLevel.description)
            } label: {
                Text("Interruption", bundle: .module)
            }
                .accessibilityElement(children: .combine)
        } header: {
            Text("Delivery", bundle: .module)
        }
    }

    @ViewBuilder private var trigger: some View {
        if let trigger = request.trigger {
            Section {
                LabeledContent {
                    Text(trigger.type)
                } label: {
                    Text("Type", bundle: .module)
                }
                    .accessibilityElement(children: .combine)

                if let nextDate = trigger.nextDate() {
                    LabeledContent("Next Trigger") {
                        NotificationTriggerLabel(nextDate)
                    }
                        .accessibilityElement(children: .combine)
                        .onAppear {
                            viewUpdate.schedule(at: nextDate)
                        }
                }
            } header: {
                Text("Trigger", bundle: .module)
            }
        }
    }

    /// Create a new notification request details view.
    /// - Parameter request: The notification request.
    public init(_ request: UNNotificationRequest) {
        self.request = request
    }
}
