//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// A ``Schedule`` describe how a ``Task`` should schedule ``Event``.
/// Use the ``Schedule``.s ``Schedule/init(start:dateComponents:end:calendar:)`` initializer to define
/// the start date, the repetition schedule, and the end time of the ``Schedule``
public struct Schedule: Codable, Sendable {
    /// The  ``Schedule/Repetition`` defines the repeating pattern of the ``Schedule``
    public enum Repetition: Codable, Sendable {
        /// The ``Schedule`` defines a ``Schedule/Repetition`` that occurs on any time matching the `DateComponents`.
        case matching(_ dateComponents: DateComponents)
        /// The ``Schedule`` defines a ``Schedule/Repetition`` that occurs at a random time between two consecutive `DateComponents`
        case randomInvervalBetween(start: DateComponents, end: DateComponents)
    }
    
    
    /// The ``Schedule/End-swift.enum`` defines the end of a ``Schedule`` by either using a finite number of events (``Schedule/End-swift.enum/numberOfEvents(_:)``),
    /// an end date (``Schedule/End-swift.enum/endDate(_:)``) or a combination of both (``Schedule/End-swift.enum/numberOfEventsOrEndDate(_:_:)``).
    public enum End: Codable, Sendable {
        /// The end of the ``Schedule`` is defined by a finite number of events.
        case numberOfEvents(Int)
        /// The end of the ``Schedule`` is defined by an end date.
        case endDate(Date)
        /// The end of the ``Schedule`` is defined by a finite number of events or an end date, whatever comes earlier.
        case numberOfEventsOrEndDate(Int, Date)
        
        
        var endDate: Date? {
            switch self {
            case let .endDate(endDate), let .numberOfEventsOrEndDate(_, endDate):
                return endDate
            case .numberOfEvents:
                return nil
            }
        }
        
        var numberOfEvents: Int? {
            switch self {
            case let .numberOfEvents(numberOfEvents), let .numberOfEventsOrEndDate(numberOfEvents, _):
                return numberOfEvents
            case .endDate:
                return nil
            }
        }
        
        
        static func minimum(_ lhs: Self, _ rhs: Self) -> End {
            switch (lhs.numberOfEvents, lhs.endDate, rhs.numberOfEvents, rhs.endDate) {
            case let (.some(numberOfEvents), .none, .none, .some(date)),
                 let (.none, .some(date), .some(numberOfEvents), .none):
                return .numberOfEventsOrEndDate(numberOfEvents, date)
            case let (nil, .some(lhsDate), nil, .some(rhsDate)):
                return .endDate(min(lhsDate, rhsDate))
            case let (.some(lhsNumberOfEvents), nil, .some(rhsNumberOfEvents), nil):
                return .numberOfEvents(min(lhsNumberOfEvents, rhsNumberOfEvents))
            case let (.some(lhsNumberOfEvents), nil, .some(rhsNumberOfEvents), .some(date)),
                 let (.some(lhsNumberOfEvents), .some(date), .some(rhsNumberOfEvents), nil):
                return .numberOfEventsOrEndDate(min(lhsNumberOfEvents, rhsNumberOfEvents), date)
            case let (.some(numberOfEvents), .some(lhsDate), nil, .some(rhsDate)),
                 let (nil, .some(lhsDate), .some(numberOfEvents), .some(rhsDate)):
                return .numberOfEventsOrEndDate(numberOfEvents, min(lhsDate, rhsDate))
            case let (.some(lhsNumberOfEvents), .some(lhsDate), .some(rhsNumberOfEvents), .some(rhsDate)):
                return .numberOfEventsOrEndDate(min(lhsNumberOfEvents, rhsNumberOfEvents), min(lhsDate, rhsDate))
            case (.none, .none, _, _), (_, _, .none, .none):
                fatalError("An end must always either have an endDate or an numberOfEvents")
            }
        }
    }
    
    
    /// The start of the ``Schedule``
    public let start: Date
    /// The  ``Schedule/Repetition`` defines the repeating pattern of the ``Schedule``
    public let repetition: Repetition
    /// The end of the ``Schedule`` using a ``Schedule/End-swift.enum``.
    public let end: End
    /// The `Calendar` used to schedule the ``Schedule`` including the time zone and locale.
    public let calendar: Calendar
    
    
    /// Creates a new ``Schedule``
    /// - Parameters:
    ///   - start: The start of the ``Schedule``
    ///   - repetition: The  ``Schedule/Repetition`` defines the repeating pattern of the ``Schedule``
    ///   - calendar: The end of the ``Schedule`` using a ``Schedule/End-swift.enum``.
    ///   - end: The `Calendar` used to schedule the ``Schedule`` including the time zone and locale.
    public init(
        start: Date,
        repetition: Repetition,
        end: End,
        calendar: Calendar = .current
    ) {
        self.start = start
        self.repetition = repetition
        self.end = end
        self.calendar = calendar
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.start = try container.decode(Date.self, forKey: .start)
        self.repetition = try container.decode(Repetition.self, forKey: .repetition)
        
        // We allow a remote instance of default configuration to use "current" as a valid string value for a calendar and
        // set it to the `.current` calendar value.
        if let calendarString = try? container.decodeIfPresent(String.self, forKey: .calendar), calendarString == "current" {
            self.calendar = .current
        } else {
            self.calendar = try container.decode(Calendar.self, forKey: .calendar)
        }
        
        self.end = try container.decode(Schedule.End.self, forKey: .end)
    }
    
    
    /// Returns all `Date`s between the provided `start` and `end` of the ``Schedule`` instance.
    /// - Parameters:
    ///   - start: The start of the requested series of `Date`s. The start date of the ``Schedule`` is used if the start date is before the ``Schedule``'s start date.
    ///   - end: The end of the requested series of `Date`s. The end (number of events or date) of the ``Schedule`` is used if the start date is after the ``Schedule``'s end.
    public func dates(from searchStart: Date? = nil, to end: End? = nil) -> [Date] {
        let end = End.minimum(end ?? self.end, self.end)
        
        var dates: [Date] = []
        var numberOfEvents = 0
        
        
        let startDateComponents: DateComponents
        switch repetition {
        case let .matching(matchingStartDateComponents):
            startDateComponents = matchingStartDateComponents
        case let .randomInvervalBetween(randomInvervalStartDateComponents, _):
            startDateComponents = randomInvervalStartDateComponents
        }
        
        
        calendar.enumerateDates(startingAfter: self.start, matching: startDateComponents, matchingPolicy: .nextTime) { result, _, stop in
            guard let result else {
                stop = true
                return
            }
            
            numberOfEvents += 1
            if result < (searchStart ?? self.start) {
                return
            }
            
            if let maxNumberOfEvents = end.numberOfEvents, numberOfEvents > maxNumberOfEvents {
                stop = true
                return
            }
            
            if let maxEndDate = end.endDate, result > maxEndDate {
                stop = true
                return
            }
            
            dates.append(result)
        }
        return dates
    }
}
