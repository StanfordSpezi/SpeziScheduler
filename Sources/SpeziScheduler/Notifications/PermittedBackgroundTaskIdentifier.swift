//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


struct PermittedBackgroundTaskIdentifier {
    static let speziSchedulerNotificationsScheduling = PermittedBackgroundTaskIdentifier(
        rawValue: "edu.stanford.spezi.scheduler.notifications-scheduling"
    )

    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}


extension PermittedBackgroundTaskIdentifier: RawRepresentable, Hashable, Sendable, Codable {}
