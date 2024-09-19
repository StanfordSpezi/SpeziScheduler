//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SwiftUI
import SpeziViews
import UserNotifications


/// Present a list of pending notifications.
public struct PendingNotificationsList: View {
    @Environment(LocalNotifications.self)
    private var localNotifications

    @State private var pendingNotifications: [UNNotificationRequest] = []

    public var body: some View {
        List {
            if pendingNotifications.isEmpty {
                ContentUnavailableView("No Notifications", systemImage: "mail.fill", description: Text("No pending notification requests."))
            } else {
                ForEach(pendingNotifications, id: \.identifier) { request in
                    NotificationRequestLabel(request)
                }
            }
        }
            .navigationTitle("Pending Notifications")
            .toolbar {
                AsyncButton {
                    pendingNotifications = await localNotifications.pendingNotificationRequests()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

            }
            .task {
                pendingNotifications = await localNotifications.pendingNotificationRequests()
            }
    }
    
    /// Create a new list of pending notifications
    public init() {}
}
