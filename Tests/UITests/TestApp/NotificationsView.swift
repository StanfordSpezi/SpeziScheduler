//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import OSLog
import Spezi
@_spi(Testing)
import SpeziScheduler
import SpeziViews
import SwiftUI
import XCTSpeziNotificationsUI


struct NotificationsView: View {
    private let logger = Logger(subsystem: "edu.stanford.spezi.TestApp", category: "NotificationsView")

    @Environment(\.notificationSettings)
    private var notificationSettings
    @Environment(\.requestNotificationAuthorization)
    private var requestNotificationAuthorization

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
                            _ = try await requestNotificationAuthorization(options: [.alert, .sound, .badge])
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
            scheduler.manuallyScheduleNotificationRefresh()
        }
    }

    private func queryAuthorization() async {
        let status = await notificationSettings().authorizationStatus
        requestAuthorization = status != .authorized && status != .denied
        logger.debug("Notification authorization is now \(status.description)")
    }
}
