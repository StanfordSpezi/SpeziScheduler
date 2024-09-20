//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import UserNotifications


extension UNNotificationInterruptionLevel: @retroactive CustomStringConvertible, @retroactive CustomDebugStringConvertible {
    public var description: String {
        switch self {
        case .passive:
            "passive"
        case .active:
            "active"
        case .timeSensitive:
            "timeSensitive"
        case .critical:
            "critical"
        @unknown default:
            "unknown(\(rawValue))"
        }
    }

    public var debugDescription: String {
        description
    }
}
