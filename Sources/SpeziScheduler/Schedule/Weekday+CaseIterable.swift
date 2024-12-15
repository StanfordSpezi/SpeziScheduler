//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension Locale.Weekday: @retroactive CaseIterable {
    /// All cases that respects the first weekday of the current locale.
    public static let allCases: [Locale.Weekday] = {
        (Calendar.current.firstWeekday..<(Calendar.current.firstWeekday + 7))
            .map { integer in
                ((integer - 1) % 7) + 1
            }
            .compactMap { ordinal in
                Locale.Weekday(ordinal: ordinal)
            }
    }()
}
