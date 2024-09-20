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


struct NotificationRequestLabel: View {
    private let request: UNNotificationRequest

    @ManagedViewUpdate private var viewUpdate

    var body: some View {
        NavigationLink {
            NotificationRequestView(request)
        } label: {
            VStack(alignment: .leading) {
                Text(request.content.title)
                    .bold()
                if let trigger = request.trigger,
                   let nextDate = trigger.nextDate() {
                    NotificationTriggerLabel(nextDate)
                        .foregroundStyle(.secondary)
                        .onAppear {
                            viewUpdate.schedule(at: nextDate)
                        }
                }
            }
        }
    }

    init(_ request: UNNotificationRequest) {
        self.request = request
    }
}
