//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziScheduler
import SpeziViews
import SwiftUI
import XCTSpeziScheduler


struct NotificationsView: View {
    @Application(\.notificationSettings)
    private var notificationSettings
    @Application(\.requestNotificationAuthorization)
    private var requestNotificationAuthorization
    @Application(\.logger)
    private var logger

    @Environment(Scheduler.self)
    private var scheduler

    @State private var requestAuthorization = false
    @State private var viewState: ViewState = .idle

    var body: some View {
        NavigationStack {
            PendingNotificationsList()
                .toolbar {
                    if requestAuthorization {
                        AsyncButton(state: $viewState) {
                            try await requestNotificationAuthorization(options: [.alert, .sound, .badge])
                            await queryAuthorization()
                            scheduler.manuallyScheduleNotificationRefresh()
                        } label: {
                            Label("Request Notification Authorization", systemImage: "alarm.waves.left.and.right.fill")
                        }
                    }
                }
        }
            .task {
                await queryAuthorization()
            }
    }

    private func queryAuthorization() async {
        let status = await notificationSettings().authorizationStatus
        requestAuthorization = status != .authorized && status != .denied
        logger.debug("Notification authorization is now \(status.description)")
    }
}
