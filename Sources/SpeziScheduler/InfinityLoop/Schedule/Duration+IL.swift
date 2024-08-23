//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension Duration {
    /// An all day duration.
    @inlinable public static var allDay: Duration {
        .hours(24)
    }

    /// Determine if a duration is all day.
    var isAllDay: Bool {
        self == .allDay
    }

    /// A duration given a number of minutes.
    ///
    /// ```swift
    /// let duration: Duration = .minutes(27)
    /// ```
    /// - Returns: A `Duration` representing a given number of minutes.
    @inlinable
    public static func minutes(_ minutes: some BinaryInteger) -> Duration {
        .seconds(minutes * 60)
        // TODO: also support Double?
    }

    /// A duration given a number of hours.
    ///
    /// ```swift
    /// let duration: Duration = .hours(4)
    /// ```
    /// - Returns: A `Duration` representing a given number of hours.
    @inlinable
    public static func hours(_ hours: some BinaryInteger) -> Duration {
        .minutes(hours * 60)
    }
}
