//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OSLog
import UserNotifications

private let logger = Logger(subsystem: "edu.stanford.spezi.scheduler", category: "Task")


/// A ``Task`` defines an instruction that is scheduled one to multiple times as defined by the ``Task/schedule`` property.
///
/// A ``Task`` can have an additional ``Task/context`` associated with it that can be used to carry application-specific context.
public final class Task<Context: Codable & Sendable>: Identifiable, Sendable {
    /// The unique identifier of the ``Task``.
    public let id: UUID
    /// The title of the ``Task``.
    public let title: String
    /// The description of the ``Task``.
    public let description: String
    /// The description of the ``Task`` as defined by a ``Schedule`` instance.
    public let schedule: Schedule
    /// Determines of the task should register local notifications to remind the user to fulfill the task
    public let notifications: Bool
    /// The customized context of the ``Task``.
    public let context: Context
    
    let events: [Event]


    fileprivate init(id: UUID, title: String, description: String, schedule: Schedule, notifications: Bool, context: Context, events: [Event]) {
        self.id = id
        self.title = title
        self.description = description
        self.schedule = schedule
        self.notifications = notifications
        self.context = context
        self.events = events

        for event in events { // ensure properties are set!
            event.taskId = id
        }
    }

    /// Creates a new ``Task`` instance.
    /// - Parameters:
    ///   - title: The title of the ``Task``.
    ///   - description: The description of the ``Task``.
    ///   - schedule: The description of the ``Task`` as defined by a ``Schedule`` instance.
    ///   - notifications: Determines of the task should register local notifications to remind the user to fulfill the task.
    ///   - context: The customized context of the ``Task``.
    public convenience init(
        // swiftlint:disable:previous function_default_parameter_at_end
        // The notification parameter is the last parameter excluding the user Context attached to a task.
        title: String,
        description: String,
        schedule: Schedule,
        notifications: Bool = false,
        context: Context
    ) {
        let id = UUID()
        var schedule = schedule
        let dates = schedule.dates()

        self.init(
            id: id,
            title: title,
            description: description,
            schedule: schedule,
            notifications: notifications,
            context: context,
            events: dates.map { date in
                Event(taskId: id, scheduledAt: date, timeZone: schedule.calendar.timeZone)
            }
        )
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

    @MainActor
    func scheduleTasks() {
        let futureEvents = events(from: .now)

        // set due timer for all future events
        for event in futureEvents {
            event.scheduleTask()
        }
    }
    
    @MainActor
    func scheduleNotifications(_ prescheduleLimit: Int) async {
        // iOS only allows up to 64 notifications to be scheduled per one app, this is why we have to do the following logic with the prescheduleLimit:
        // We don't check notifications here in case notifications might becomes mutable in the future.
        
        // Cancel all future notifications to ensure that we only register up to the defined limit.
        let eventList = events(from: .now.addingTimeInterval(.leastNonzeroMagnitude))

        for event in eventList {
            event.cancelNotification()
        }

        guard notifications else {
            return
        }

        // We only schedule the future events.
        let futureEvents = eventList
            .filter { !$0.complete }
            .sorted { $0.scheduledAt < $1.scheduledAt }
        // Only allows up to 64 notifications to be scheduled per one app, we ensure that we do not exceed the preschedule limit.
            .prefix(prescheduleLimit)

        let notificationCenter = UNUserNotificationCenter.current()
        let status = await notificationCenter.notificationSettings().authorizationStatus

        if status == .notDetermined || status == .denied {
            for event in futureEvents {
                // set for visibility in tests
                event.log = "Could not register due to missing permissions ..."
            }
            return
        }

        for event in futureEvents where event.notification == nil {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = description

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(event.scheduledAt.timeIntervalSince(Date.now), TimeInterval.leastNonzeroMagnitude),
                repeats: false
            )

            let identifier = UUID()
            let request = UNNotificationRequest(identifier: identifier.uuidString, content: content, trigger: trigger)

            do {
                try await notificationCenter.add(request)
                event.scheduledNotification(id: identifier)
            } catch {
                logger.error("Could not schedule task as local notification: \(error).")
                event.log = "Could not schedule task as local notification: \(error)"
            }
        }
    }

    
    /// Returns all ``Event``s corresponding to a ``Task`` with the `start` and `end` parameters.
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
}


extension Task: Hashable {
    public static func == (lhs: Task, rhs: Task) -> Bool {
        lhs.id == rhs.id
    }


    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}


extension Task: Codable {
    enum CodingKeys: CodingKey {
        case id
        case title
        case description
        case schedule
        case notifications
        case context
        case events
    }


    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decode(UUID.self, forKey: .id)
        let title = try container.decode(String.self, forKey: .title)
        let description = try container.decode(String.self, forKey: .description)
        let schedule = try container.decode(Schedule.self, forKey: .schedule)
        let notifications = try container.decode(Bool.self, forKey: .notifications)
        let context = try container.decode(Context.self, forKey: .context)
        let events = try container.decode([Event].self, forKey: .events)

        self.init(id: id, title: title, description: description, schedule: schedule, notifications: notifications, context: context, events: events)
    }
    

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(schedule, forKey: .schedule)
        try container.encode(notifications, forKey: .notifications)
        try container.encode(context, forKey: .context)
        try container.encode(events, forKey: .events)
    }
}
