//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

#if canImport(BackgroundTasks)
import BackgroundTasks


@available(macOS, unavailable)
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
#endif
