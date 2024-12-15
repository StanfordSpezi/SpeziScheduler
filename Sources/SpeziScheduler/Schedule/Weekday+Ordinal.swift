//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension Locale.Weekday {
    /// Retrieve the ordinal of the weekday.
    public var ordinal: Int {
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
    
    /// Initialize the weekday from it's ordinal representation.
    /// - Parameter ordinal: The ordinal. A value between 1 and 7.
    public init?(ordinal: Int) {
        switch ordinal {
        case 1:
            self = .sunday
        case 2:
            self = .monday
        case 3:
            self = .tuesday
        case 4:
            self = .wednesday
        case 5:
            self = .thursday
        case 6:
            self = .friday
        case 7:
            self = .saturday
        default:
            return nil
        }
    }
    
    /// Get the weekday from a date.
    /// - Parameter date: The date.
    public init(from date: Date) {
        let weekdayOrdinal = Calendar.current.component(.weekday, from: date)
        guard let weekday = Locale.Weekday(ordinal: weekdayOrdinal) else {
            preconditionFailure("Failed to derive weekday from ordinal \(weekdayOrdinal)")
        }
        self = weekday
    }
}
