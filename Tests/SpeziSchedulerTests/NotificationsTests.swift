//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@testable import SpeziScheduler
import Testing


@Suite
struct NotificationsTests {
    @Test
    func sharedIdPrefix() {
        #expect(SchedulerNotifications.baseTaskNotificationId.starts(with: SchedulerNotifications.baseNotificationId))
        #expect(SchedulerNotifications.baseEventNotificationId.starts(with: SchedulerNotifications.baseNotificationId))
    }
}
