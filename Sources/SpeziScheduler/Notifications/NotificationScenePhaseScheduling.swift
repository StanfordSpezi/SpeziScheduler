//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


struct NotificationScenePhaseScheduling: ViewModifier {
    @Environment(Scheduler.self)
    private var scheduler: Scheduler? // modifier is injected by SchedulerNotifications and it doesn't have a direct scheduler dependency
    @Environment(SchedulerNotifications.self)
    private var schedulerNotifications

    @Environment(\.scenePhase)
    private var scenePhase

    nonisolated init() {}

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase, initial: true) {
                guard let scheduler else {
                    // by the time the modifier appears, the scheduler is injected
                    return
                }

                switch scenePhase {
                case .active:
                    _Concurrency.Task { @MainActor in
                        await schedulerNotifications.checkForInitialScheduling(scheduler: scheduler)
                    }
                case .background, .inactive:
                    break
                @unknown default:
                    break
                }
            }
    }
}
