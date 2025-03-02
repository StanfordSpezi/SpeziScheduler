//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziScheduler
import UserNotifications


actor TestAppStandard: Standard, SchedulerNotificationsConstraint {
    @MainActor
    func notificationContent(for task: borrowing Task, content: borrowing UNMutableNotificationContent) {}
}


class TestAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration(standard: TestAppStandard()) {
            Scheduler()
            SchedulerNotifications()
            TestAppScheduler()
        }
    }
}
