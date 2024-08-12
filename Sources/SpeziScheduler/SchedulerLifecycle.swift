//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SwiftUI


struct SchedulerLifecycle<Context: Codable & Sendable>: ViewModifier {
    @Environment(Scheduler<Context>.self)
    private var scheduler

    @Environment(\.scenePhase)
    private var scenePhase

    nonisolated init() {}

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) {
                guard scenePhase == .active else {
                    return
                }

                scheduler.handleActiveScenePhase()
            }
        #if !os(watchOS)
            .onReceive(NotificationCenter.default.publisher(for: _Application.willTerminateNotification)) { _ in
                scheduler.handleApplicationWillTerminate()
            }
        #endif
    }
}
