//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

#if !os(watchOS) && canImport(BackgroundTasks)
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
        #if compiler(>=6.2) // even though the docs say this is available starting with iOS 13, only Xcode 26 seems to know about it...
        case .immediateRunIneligible:
            "immediateRunIneligible"
        #endif
        @unknown default:
            "BGTaskSchedulerErrorCode(rawValue: \(rawValue))"
        }
    }
}
#endif
