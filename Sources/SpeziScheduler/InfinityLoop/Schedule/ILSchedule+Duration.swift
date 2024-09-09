//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


extension ILSchedule {
    /// The duration of an occurrence.
    ///
    /// While we maintain atto-second accuracy for arithmetic operations on duration, the schedule will always retrieve the duration in a resolution of seconds.
    public enum Duration {
        /// An all-day occurrence.
        ///
        /// The start the will always the the `startOfDay` date.
        case allDay
        /// An occurrence that
        case tillEndOfDay
        /// Fixed length occurrence.
        case duration(Swift.Duration)
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


extension ILSchedule.Duration: Hashable, Sendable {}


extension ILSchedule.Duration: CustomStringConvertible {
    public var description: String {
        switch self {
        case .allDay:
            "allDay"
        case .tillEndOfDay:
            "tillEndOfDay"
        case let .duration(duration):
            duration.description
        }
    }
}


extension ILSchedule.Duration {
    // Duration encodes itself as an unkeyed container with high and low Int64 values.
    // See https://github.com/swiftlang/swift/blob/eafb40588c17bf8f6405823f8bedb9428694a9bd/stdlib/public/core/Duration.swift#L238-L240.
    // SwiftData doesn't support unkeyed containers and crashes. Therefore, we explicitly construct a new Int128 type from it
    // and encode the duration this way.
    // A second approach could be to create the `Int128(_low: duration._low, _high: duration._high)` ourselves.
    // However, the SwiftData encoder "has not implemented support for Int128". Good damn Apple.
    //
    // So, as SwiftData requires the type layout to be equal to the CodingKeys, we need to created this MappedDuration type here.
    struct MappedDuration {
        private let high: Int64
        private let low: UInt64

        var duration: Swift.Duration {
            Swift.Duration(_high: high, low: low)
        }

        init(from duration: Swift.Duration) {
            self.high = duration._high
            self.low = duration._low
        }
    }

    enum SwiftDataDuration {
        case allDay
        case tillEndOfDay
        case duration(MappedDuration)
    }
}


extension ILSchedule.Duration.MappedDuration: Hashable, Sendable, Codable {}


extension ILSchedule.Duration.SwiftDataDuration: Hashable, Sendable, Codable {}


extension ILSchedule.Duration.SwiftDataDuration: CustomStringConvertible {
    var description: String {
        switch self {
        case .allDay:
            "allDay"
        case .tillEndOfDay:
            "tillEndOfDay"
        case let .duration(duration):
            duration.duration.description
        }
    }
}


extension ILSchedule.Duration.SwiftDataDuration {
    init(from duration: ILSchedule.Duration) {
        switch duration {
        case .allDay:
            self = .allDay
        case .tillEndOfDay:
            self = .tillEndOfDay
        case .duration(let duration):
            self = .duration(ILSchedule.Duration.MappedDuration(from: duration))
        }
    }
}


extension ILSchedule.Duration {
    init(from duration: ILSchedule.Duration.SwiftDataDuration) {
        switch duration {
        case .allDay:
            self = .allDay
        case .tillEndOfDay:
            self = .tillEndOfDay
        case let .duration(mapped):
            self = .duration(mapped.duration)
        }
    }
}
