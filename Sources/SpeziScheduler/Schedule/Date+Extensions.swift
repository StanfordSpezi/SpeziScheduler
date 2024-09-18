//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension Date {
    /// The start of day of `now`.
    public static var today: Date {
        Calendar.current.startOfDay(for: .now)
    }

    /// The start of day of tomorrow.
    public static var tomorrow: Date {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .today) else {
            preconditionFailure("Failed to construct tomorrow from base \(Date.today).")
        }
        return tomorrow
    }

    /// The start of day of yesterday.
    public static var yesterday: Date {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: -1, to: .today) else {
            preconditionFailure("Failed to construct tomorrow from base \(Date.today).")
        }
        return tomorrow
    }
    
    /// The start of day in one week (7 days).
    public static var nextWeek: Date {
        guard let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: .today) else {
            preconditionFailure("Failed to construct tomorrow from base \(Date.today).")
        }
        return nextWeek
    }
}
