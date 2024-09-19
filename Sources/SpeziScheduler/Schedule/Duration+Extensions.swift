//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


extension Duration {
    /// A duration given a number of minutes.
    ///
    /// ```swift
    /// let duration: Duration = .minutes(27)
    /// ```
    /// - Returns: A `Duration` representing a given number of minutes.
    @inlinable
    public static func minutes(_ minutes: some BinaryInteger) -> Duration {
        .seconds(minutes * 60)
    }

    /// A duration given a number of minutes.
    ///
    /// Creates a new duration given a number of minutes by converting into the closest second scale value.
    ///
    /// ```swift
    /// let duration: Duration = .minutes(27.5)
    /// ```
    /// - Returns: A `Duration` representing a given number of minutes.
    @inlinable
    public static func minutes(_ minutes: Double) -> Duration {
        .seconds(minutes * 60)
    }

    /// A duration given a number of hours.
    ///
    /// ```swift
    /// let duration: Duration = .hours(4)
    /// ```
    /// - Returns: A `Duration` representing a given number of hours.
    @inlinable
    public static func hours(_ hours: some BinaryInteger) -> Duration {
        .seconds(hours * 60 * 60)
    }

    /// A duration given a number of hours.
    ///
    /// Creates a new duration given a number of hours by converting into the closest second scale value.
    ///
    /// ```swift
    /// let duration: Duration = .hours(4.5)
    /// ```
    /// - Returns: A `Duration` representing a given number of hours.
    @inlinable
    public static func hours(_ hours: Double) -> Duration {
        .seconds(hours * 60 * 60)
    }

    /// A duration given a number of days.
    ///
    /// ```swift
    /// let duration: Duration = .days(2)
    /// ```
    /// - Returns: A `Duration` representing a given number of days.
    @inlinable
    public static func days(_ days: some BinaryInteger) -> Duration {
        .seconds(days * 60 * 60 * 24)
    }

    /// A duration given a number of days.
    ///
    /// ```swift
    /// let duration: Duration = .days(2.5)
    /// ```
    /// - Returns: A `Duration` representing a given number of days.
    @inlinable
    public static func days(_ days: Double) -> Duration {
        .seconds(days * 60 * 60 * 24)
    }

    /// A duration given a number of weeks.
    ///
    /// ```swift
    /// let duration: Duration = .weeks(4)
    /// ```
    /// - Returns: A `Duration` representing a given number of weeks.
    @inlinable
    public static func weeks(_ weeks: some BinaryInteger) -> Duration {
        .seconds(weeks * 60 * 60 * 24 * 7)
    }

    /// A duration given a number of weeks.
    ///
    /// ```swift
    /// let duration: Duration = .weeks(3.5)
    /// ```
    /// - Returns: A `Duration` representing a given number of weeks.
    @inlinable
    public static func weeks(_ weeks: Double) -> Duration {
        .seconds(weeks * 60 * 60 * 24 * 7)
    }
}
