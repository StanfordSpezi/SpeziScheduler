//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Combine
import Foundation
import SwiftData


#warning("Make the types all structs again?")
#warning("Rename to Job")
/// A ``Task`` defines an instruction that is scheduled one to multiple times as defined by the ``Task/schedule`` property.
///
/// A ``Task`` can have an additional ``Task/context`` associated with it that can be used to carry application-specific context.
@Model
public final class Task<Context: Codable & Sendable>: Identifiable, Hashable, @unchecked Sendable, TaskReference {
    enum CodingKeys: CodingKey {
        case id
        case title
        case description
        case schedule
        case notifications
        case context
        case events
    }
    
    
    /// The unique identifier of the ``Task``.
    public let id: UUID
    #warning("TODO: Remove the title and find a better way to customize notifications ...")
    /// The title of the ``Task``.
    public let title: String
    /// The description of the ``Task`` as defined by a ``Schedule`` instance.
    public let schedule: Schedule
    /// Determines of the task should register local notifications to remind the user to fulfill the task
    public let notifications: Bool
    /// The customized context of the ``Task``.
    public let context: Context
    
    @Relationship(deleteRule: .cascade, inverse: \Event.taskReference) private(set) var events: [Event]
    
    
    /// Creates a new ``Task`` instance.
    /// - Parameters:
    ///   - title: The title of the ``Task``.
    ///   - description: The description of the ``Task``.
    ///   - schedule: The description of the ``Task`` as defined by a ``Schedule`` instance.
    ///   - notifications: Determines of the task should register local notifications to remind the user to fulfill the task.
    ///   - context: The customized context of the ``Task``.
    public init(
        // swiftlint:disable:previous function_default_parameter_at_end
        // The notification paramter is the last parameter excluding the user Context attached to a task.
        title: String,
        schedule: Schedule,
        notifications: Bool = false,
        context: Context
    ) {
        self.id = UUID()
        self.title = title
        self.schedule = schedule
        self.notifications = notifications
        self.context = context
        self.events = [] // We first need to fully initalize the type.
        self.events = schedule.dates().map { date in Event(scheduledAt: date, eventsContainer: self) }
    }
    
    
    public static func == (lhs: Task, rhs: Task) -> Bool {
        lhs.id == rhs.id
    }
    
    
    func contains(scheduledNotificationWithId notification: String) -> Bool {
        guard notifications else {
            return false
        }
        
        // See if the notification identifier is persisted in the events that have already been scheduled.
        return events(to: .endDate(.now)).contains { event in
            event.notification?.uuidString == notification
        }
    }
    
    func scheduleTask() {
        // We only schedule the future events.
        let futureEvents = events(from: .now)
        
        // Set the timers for all events.
        for futureEvent in futureEvents {
            futureEvent.scheduleTask()
        }
    }
    
    func scheduleNotification(_ prescheduleLimit: Int) async {
        // iOS only allows up to 64 notifications to be scheduled per one app, this is why we have to do the following logic with the prescheduleLimit:
        // We don't check notifications here in case notifications might becomes mutable in the future.
        
        // Cancel all future notifications to ensure that we only register up to the defined limit.
        let futureEvents = events(from: .now.addingTimeInterval(.leastNonzeroMagnitude))
        
        for futureEvent in futureEvents {
            futureEvent.cancelNotification()
        }
        
        if notifications {
            // We only schedule the future events.
            // Only allows up to 64 notifications to be scheduled per one app, we ensure that we do not exceed the preschedule limit.
            for futureEvent in futureEvents.filter({ !$0.complete }).sorted(by: { $0.scheduledAt < $1.scheduledAt }).prefix(prescheduleLimit) {
                await futureEvent.scheduleNotification()
            }
        }
    }
    
    
    /// Returns all ``Event``s corresponding to a ``Task`` withi the `start` and `end` parameters.
    /// - Parameters:
    ///   - start: The start of the requested series of `Event`s. The start date of the ``Task/schedule`` is used if the start date is before the ``Task/schedule``'s start date.
    ///   - end: The end of the requested series of `Event`s. The end (number of events or date) of the ``Task/schedule`` is used if the start date is after the ``Task/schedule``'s end.
    public func events(from start: Date? = nil, to end: Schedule.End? = nil) -> [Event] {
        var filteredEvents: [Event] = []
        let sortedEvents = events.sorted { $0.scheduledAt < $1.scheduledAt }
        
        for event in sortedEvents {
            // Filter out all events before the start date.
            if let start, event.scheduledAt < start {
                continue
            }
            
            // If there is a maximum number of elements and we are past that point we can return and end the appending of sorted events.
            if let maxNumberOfEvents = end?.numberOfEvents, filteredEvents.count >= maxNumberOfEvents {
                break
            }
            
            // We exit the loop if we are past the end date
            if let endDate = end?.endDate, event.scheduledAt >= endDate {
                break
            }
            
            filteredEvents.append(event)
        }
        
        return filteredEvents
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
