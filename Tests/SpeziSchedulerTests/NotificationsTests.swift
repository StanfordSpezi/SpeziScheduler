//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@testable import SpeziScheduler
import UserNotifications
import XCTest


final class NotificationsTests: XCTestCase {
    func testSharedIdPrefix() {
        XCTAssert(SchedulerNotifications.baseTaskNotificationId.starts(with: SchedulerNotifications.baseNotificationId))
        XCTAssert(SchedulerNotifications.baseEventNotificationId.starts(with: SchedulerNotifications.baseNotificationId))

        // TODO: also test that for the event and task methods?
    }
}
