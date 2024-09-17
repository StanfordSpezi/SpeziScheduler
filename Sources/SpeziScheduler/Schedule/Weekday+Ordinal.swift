//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension Locale.Weekday {
    var ordinal: Int { // TODO: this is what we want right
        switch self {
        case .sunday:
            1
        case .monday:
            2
        case .tuesday:
            3
        case .wednesday:
            4
        case .thursday:
            5
        case .friday:
            6
        case .saturday:
            7
        @unknown default:
            preconditionFailure("A new weekday appeared we don't know about: \(self)")
        }
    }
}
