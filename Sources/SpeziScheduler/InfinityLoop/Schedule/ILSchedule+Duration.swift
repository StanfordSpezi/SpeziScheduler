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
    public struct Duration {
        let guts: _Duration


        fileprivate var duration: Swift.Duration { // TODO: make it public?
            switch guts {
            case .allDay:
                .seconds(24 * 60 * 60)
            case let .duration(duration):
                duration.duration
            }
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

    enum _Duration { // swiftlint:disable:this type_name
        case allDay
        case duration(MappedDuration)
    }
}


extension ILSchedule.Duration.MappedDuration: Hashable, Sendable, Codable {}


extension ILSchedule.Duration._Duration: Hashable, Sendable, Codable {}


extension ILSchedule.Duration: Hashable, Sendable, Codable {}
// TODO: RawRepresentable conformance, but would require to make guts public or we never store it in Schedule?


extension ILSchedule.Duration: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.duration < rhs.duration
    }
}


extension ILSchedule.Duration: CustomStringConvertible {
    public var description: String {
        switch guts {
        case .allDay:
            "allDay"
        case let .duration(duration):
            duration.duration.description
        }
    }
}


extension ILSchedule.Duration { // TODO: move both up?
    /// An all-day occurrence.
    public static var allDay: ILSchedule.Duration {
        ILSchedule.Duration(guts: .allDay)
    }


    /// Fixed length occurrence.
    /// - Parameter duration: The duration.
    /// - Returns: Returns the schedule duration instance.
    public static func duration(_ duration: Swift.Duration) -> ILSchedule.Duration {
        ILSchedule.Duration(guts: .duration(MappedDuration(from: duration)))
    }
}


extension ILSchedule.Duration {
    /// Determine if a duration is all day.
    public var isAllDay: Bool {
        guts == .allDay
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


extension ILSchedule.Duration: DurationProtocol {
    public static var zero: ILSchedule.Duration {
        .duration(.zero)
    }

    public static func + (lhs: ILSchedule.Duration, rhs: ILSchedule.Duration) -> ILSchedule.Duration {
        .duration(lhs.duration + rhs.duration)
    }

    public static func - (lhs: ILSchedule.Duration, rhs: ILSchedule.Duration) -> ILSchedule.Duration {
        .duration(lhs.duration - rhs.duration)
    }

    public static func / (lhs: ILSchedule.Duration, rhs: Int) -> ILSchedule.Duration {
        .duration(lhs.duration / rhs)
    }

    public static func * (lhs: ILSchedule.Duration, rhs: Int) -> ILSchedule.Duration {
        .duration(lhs.duration * rhs)
    }

    public static func / (lhs: ILSchedule.Duration, rhs: ILSchedule.Duration) -> Double {
        lhs.duration / rhs.duration
    }
}
