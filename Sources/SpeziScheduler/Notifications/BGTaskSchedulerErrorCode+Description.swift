//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import BackgroundTasks


extension BGTaskScheduler.Error.Code: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .notPermitted:
            "notPermitted"
        case .tooManyPendingTaskRequests:
            "tooManyPendingTaskRequests"
        case .unavailable:
            "unavailable"
        @unknown default:
            "BGTaskSchedulerErrorCode(rawValue: \(rawValue))"
        }
    }
}
