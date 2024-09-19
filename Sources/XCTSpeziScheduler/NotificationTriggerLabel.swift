//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SwiftUI
import UserNotifications


struct NotificationTriggerLabel: View {
    private let trigger: UNNotificationTrigger

    var body: some View {
        if let nextDate = trigger.nextDate() {
            Text("in \(Text(.currentDate, format: SystemFormatStyle.DateOffset(to: nextDate, sign: .never)))")
        }
    }

    init(_ trigger: UNNotificationTrigger) {
        self.trigger = trigger
    }
}
