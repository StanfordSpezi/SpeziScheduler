//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// A ``Schedule`` describe how a ``Task`` should schedule ``Event``.
/// Use the ``Schedule``.s ``Schedule/init(start:repetition:end:calendar:)`` initializer to define
/// the start date, the repetition schedule (``Schedule/Repetition-swift.enum``), and the end time (``Schedule/End-swift.enum``) of the ``Schedule``
public struct Schedule: Sendable {
    /// The  ``Schedule/Repetition-swift.enum`` defines the repeating pattern of the ``Schedule``
    public enum Repetition: Codable, Sendable {
        /// The ``Schedule`` defines a ``Schedule/Repetition-swift.enum`` that occurs on any time matching the `DateComponents`.
        case matching(_ dateComponents: DateComponents)
        /// The ``Schedule`` defines a ``Schedule/Repetition-swift.enum`` that occurs at a random time between two consecutive `DateComponents`
        case randomBetween(start: DateComponents, end: DateComponents)
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
    /// The  ``Schedule/Repetition-swift.enum`` defines the repeating pattern of the ``Schedule``
    public let repetition: Repetition
    /// The end of the ``Schedule`` using a ``Schedule/End-swift.enum``.
    public let end: End
    /// The `Calendar` used to schedule the ``Schedule`` including the time zone and locale.
    public let calendar: Calendar
    
    private var randomDisplacements: [Date: TimeInterval]


    fileprivate init(start: Date, repetition: Repetition, end: End, calendar: Calendar, randomDisplacements: [Date: TimeInterval]) {
        self.start = start
        self.repetition = repetition
        self.end = end
        self.calendar = calendar
        self.randomDisplacements = randomDisplacements
    }

    /// Creates a new ``Schedule``
    /// - Parameters:
    ///   - start: The start of the ``Schedule``
    ///   - repetition: The  ``Schedule/Repetition-swift.enum`` defines the repeating pattern of the ``Schedule``
    ///   - calendar: The end of the ``Schedule`` using a ``Schedule/End-swift.enum``.
    ///   - end: The `Calendar` used to schedule the ``Schedule`` including the time zone and locale.
    public init(
        start: Date,
        repetition: Repetition,
        end: End,
        calendar: Calendar = .current
    ) {
        self.init(start: start, repetition: repetition, end: end, calendar: calendar, randomDisplacements: [:])
    }
    
    
    /// Returns all `Date`s between the provided `start` and `end` of the ``Schedule`` instance.
    /// - Parameters:
    ///   - searchStart: The start of the requested series of `Date`s. The start date of the ``Schedule`` is used if the start date is before the ``Schedule``'s start date.
    ///   - end: The end of the requested series of `Date`s. The end (number of events or date) of the ``Schedule`` is used if the start date is after the ``Schedule``'s end.
    mutating func dates(from searchStart: Date? = nil, to end: End? = nil) -> [Date] {
        let end = End.minimum(end ?? self.end, self.end)
        
        var dates: [Date] = []
        
        
        let startDateComponents: DateComponents
        switch repetition {
        case let .matching(matchingStartDateComponents):
            startDateComponents = matchingStartDateComponents
        case let .randomBetween(randomBetweenStartDateComponents, _):
            startDateComponents = randomBetweenStartDateComponents
        }


        calendar.enumerateDates(startingAfter: self.start, matching: startDateComponents, matchingPolicy: .nextTime) { result, _, stop in
            guard let result else {
                stop = true
                return
            }
            
            if result < (searchStart ?? self.start) {
                return
            }
            
            if let maxNumberOfEvents = end.numberOfEvents, dates.count >= maxNumberOfEvents {
                stop = true
                return
            }
            
            if let maxEndDate = end.endDate, result > maxEndDate {
                stop = true
                return
            }
            
            switch repetition {
            case .matching:
                dates.append(result)
            case let .randomBetween(_, randomBetweenEndDateComponents):
                let randomDisplacement: TimeInterval
                if let storedRandomDisplacement = randomDisplacements[result] {
                    randomDisplacement = storedRandomDisplacement
                } else {
                    randomDisplacement = newRandomDisplacementFor(date: result, randomBetweenEndDateComponents: randomBetweenEndDateComponents)
                    insertRandomDisplacement(for: result, randomDisplacement)
                }
                
                dates.append(result.addingTimeInterval(randomDisplacement))
            }
        }
        
        return dates
    }
    
    private func newRandomDisplacementFor(date: Date, randomBetweenEndDateComponents: DateComponents) -> Double {
        let resultEndDate = calendar
            .nextDate(
                after: date,
                matching: randomBetweenEndDateComponents,
                matchingPolicy: .nextTime
            )
            ?? date
        
        let timeInterval = resultEndDate.timeIntervalSince(date)
        return Double.random(in: 0...timeInterval)
    }
    
    private mutating func insertRandomDisplacement(for date: Date, _ timeInverval: TimeInterval?) {
        randomDisplacements[date] = timeInverval
    }
}


extension Schedule: Codable {
    enum CodingKeys: CodingKey {
        case start
        case repetition
        case end
        case calendar
        case randomDisplacements
    }


    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.start = try container.decode(Date.self, forKey: .start)
        self.repetition = try container.decode(Repetition.self, forKey: .repetition)
        self.end = try container.decode(Schedule.End.self, forKey: .end)

        // We allow a remote instance of default configuration to use "current" as a valid string value for a calendar and
        // set it to the `.current` calendar value.
        if let calendarString = try? container.decodeIfPresent(String.self, forKey: .calendar), calendarString == "current" {
            self.calendar = .current
        } else {
            self.calendar = try container.decode(Calendar.self, forKey: .calendar)
        }

        self.randomDisplacements = try container.decodeIfPresent([Date: TimeInterval].self, forKey: .randomDisplacements) ?? [:]
    }


    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(start, forKey: .start)
        try container.encode(repetition, forKey: .repetition)
        try container.encode(end, forKey: .end)
        try container.encode(calendar, forKey: .calendar)
        try container.encode(randomDisplacements, forKey: .randomDisplacements)
    }
}
