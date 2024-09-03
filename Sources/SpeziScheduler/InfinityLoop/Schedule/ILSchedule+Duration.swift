//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


extension ILSchedule {
    /// The duration of an occurrence.
    public enum Duration {
        /// An all-day occurrence.
        case allDay
        /// Fixed length occurrence.
        case duration(Swift.Duration)
    }
}


extension ILSchedule.Duration: Equatable, Sendable {} // TODO: comparable? range expressions?
// TODO: AdditiveArithmetic?


extension ILSchedule.Duration: CustomStringConvertible {
    public var description: String {
        switch self {
        case .allDay:
            "allDay"
        case let .duration(duration):
            duration.description
        }
    }
}


extension ILSchedule.Duration: Codable {
    private enum CodingKeys: String, CodingKey {
        case allDay
        case duration
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let allDay = try container.decodeIfPresent(Bool.self, forKey: .allDay)
        if allDay != nil {
            self = .allDay
        } else {
            let duration = try container.decode(Swift.Duration.self, forKey: .duration)
            self = .duration(duration)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .allDay:
            try container.encode(true, forKey: .allDay)
        case let .duration(duration):
            try container.encode(duration, forKey: .duration)
        }
    }
}


extension ILSchedule.Duration {
    /// Determine if a duration is all day.
    public var isAllDay: Bool {
        self == .allDay
    }

    /// A duration given a number of seconds.
    ///
    /// ```swift
    /// let duration: Duration = .seconds(42)
    /// ```
    /// - Returns: A `Duration` representing a given number of seconds.
    @inlinable
    public static func seconds(_ seconds: some BinaryInteger) -> ILSchedule.Duration {
        .duration(.seconds(seconds))
    }

    /// A duration given a number of minutes.
    ///
    /// ```swift
    /// let duration: Duration = .minutes(27)
    /// ```
    /// - Returns: A `Duration` representing a given number of minutes.
    @inlinable
    public static func minutes(_ minutes: some BinaryInteger) -> ILSchedule.Duration {
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
    public static func minutes(_ minutes: Double) -> ILSchedule.Duration {
        .duration(.seconds(minutes * 60))
    }

    /// A duration given a number of hours.
    ///
    /// ```swift
    /// let duration: Duration = .hours(4)
    /// ```
    /// - Returns: A `Duration` representing a given number of hours.
    @inlinable
    public static func hours(_ hours: some BinaryInteger) -> ILSchedule.Duration {
        .minutes(hours * 60)
    }

    /// A duration given a number of hours.
    ///
    /// Creates a new duration given a number of hours by converting into the closest second scale value.
    ///
    /// ```swift
    /// let duration: Duration = .hours(4)
    /// ```
    /// - Returns: A `Duration` representing a given number of hours.
    public static func hours(_ hours: Double) -> ILSchedule.Duration {
        .minutes(hours * 60)
    }
}
