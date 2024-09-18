//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import UserNotifications


/// Minimal model of the legacy event model to retrieve data to provide some interoperability with the legacy version.
struct LegacyEventModel {
    let notification: UUID?
}


/// Minimal model of the legacy task model to retrieve data to provide some interoperability with the legacy version.
struct LegacyTaskModel {
    let id: UUID
    let notifications: Bool
    let events: [LegacyEventModel]
}


extension LegacyEventModel: Decodable, Hashable, Sendable {}


extension LegacyTaskModel: Decodable, Hashable, Sendable {}


extension LegacyEventModel {
    func cancelNotification() {
        guard let notification else {
            return
        }

        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [notification.uuidString])
        center.removePendingNotificationRequests(withIdentifiers: [notification.uuidString])
    }
}