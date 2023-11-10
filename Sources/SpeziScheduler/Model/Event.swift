//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import UserNotifications


/// An  ``Event`` describes a unique point in time when a ``Task`` is scheduled. Use events to display the recurring nature of a ``Task`` to a user.
///
/// Use the  ``Event/complete(_:)`` and ``Event/toggle()`` functions to mark an Event as complete. You can access the scheduled date of an
/// event using ``Event/scheduledAt`` and the completed date using the ``Event/completedAt`` properties.
@Observable
public final class Event: Identifiable, @unchecked Sendable {
    // these properties are passed in by the parent task
    var taskId: UUID?
    var storage: AnyStorage?


    public private(set) var state: EventState

    /// The timezone this Event was created with.
    private var timeZone: TimeZone
    internal private(set) var notification: UUID?

    private var dueTimer: Timer?
    /// Only used for test purposes to identify the current state of the log in the UI testing application.
    var log: String?

    public var id: String {
        "\(taskId?.uuidString ?? "").\(state.description)"
    }

    /// The date when the ``Event`` is scheduled at.
    public var scheduledAt: Date {
        state.scheduledAt
    }

    public var due: Bool { // TODO: docs
        if case .overdue = state {
            return true
        }
        return false
    }

    /// Indicates if the ``Event`` is complete.
    public var complete: Bool {
        if case .completed = state {
            return true
        }
        return false
    }

    // TODO var completedAt: Date? { get set }


    // swiftlint:disable:next function_default_parameter_at_end
    fileprivate init(state: EventState, taskId: UUID? = nil, timeZone: TimeZone, notification: UUID? = nil) {
        self.taskId = taskId
        self.state = state
        self.notification = notification
        self.timeZone = timeZone

        if timeZone != Calendar.current.timeZone {
            self.state = state.timeZoneAdjusted(from: timeZone)
            self.timeZone = Calendar.current.timeZone
        }
    }

    convenience init(taskId: UUID, scheduledAt: Date, timeZone: TimeZone) {
        self.init(state: .scheduled(at: scheduledAt), taskId: taskId, timeZone: timeZone)
    }


    /// Use this function to mark an ``Event`` as complete or incomplete.
    /// - Parameter newValue: The new state of the ``Event``.
    @MainActor
    public func complete(_ newValue: Bool) {
        if newValue {
            state = .completed(at: Date(), scheduled: state.scheduledAt)
            if let notification {
                let notificationCenter = UNUserNotificationCenter.current()
                notificationCenter.removeDeliveredNotifications(withIdentifiers: [notification.uuidString])
                notificationCenter.removePendingNotificationRequests(withIdentifiers: [notification.uuidString])
            }
        } else {
            // actually we have to check if it was overdue here now!
            state = .scheduled(at: state.scheduledAt)
        }

        storage?.signalChange()
    }

    /// Toggle the  ``complete`` state.
    @MainActor
    public func toggle() {
        if case .completed = state {
            complete(false)
        } else {
            complete(true)
        }
    }


    @MainActor
    func markOverdue() {
        if case let .scheduled(at) = state {
            state = .overdue(since: at)
            storage?.signalChange()
        }
    }

    @MainActor
    func scheduleTask() {
        guard case .scheduled = state, dueTimer == nil else {
            return
        }

        // schedule the due timer
        let timer = Timer(
            timeInterval: max(Date.now.distance(to: scheduledAt), .leastNonzeroMagnitude),
            repeats: false,
            block: { timer in
                timer.invalidate()
                _Concurrency.Task { @MainActor in
                    self.markOverdue()
                    self.dueTimer = nil
                }
            }
        )

        RunLoop.main.add(timer, forMode: .common)
        dueTimer = timer
    }

    @MainActor
    func scheduledNotification(id: UUID) {
        self.log = "Registered at \(scheduledAt.formatted(date: .abbreviated, time: .complete))"
        self.notification = id
        storage?.signalChange()
    }

    @MainActor
    func cancelNotification() {
        guard let notification else {
            return
        }

        guard complete || state.scheduledAt > .now else {
            self.log = "Notification Delivered - Not yet Completed"
            return
        }

        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [notification.uuidString])
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notification.uuidString])

        self.notification = nil
        self.log = "No Notification - Complete: \(complete)"
        storage?.signalChange()
    }


    deinit {
        dueTimer?.invalidate()
    }
}


extension Event: Codable {
    enum CodingKeys: String, CodingKey {
        case notification
        case scheduledAt
        case completedAt
        case timeZone
    }


    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let notification = try container.decodeIfPresent(UUID.self, forKey: .notification)
        let timeZone = try container.decodeIfPresent(TimeZone.self, forKey: .timeZone)
            ?? Calendar.current.timeZone // TODO: can we retrieve the timeZone from the Schedule?
        let state: EventState

        let scheduledAtDate = try container.decode(Date.self, forKey: .scheduledAt)
        if let completedAtDate = try container.decodeIfPresent(Date.self, forKey: .completedAt) {
            state = .completed(at: completedAtDate, scheduled: scheduledAtDate)
        } else if scheduledAtDate <= Date.now {
            state = .overdue(since: scheduledAtDate)
        } else {
            state = .scheduled(at: scheduledAtDate)
        }

        self.init(state: state, timeZone: timeZone, notification: notification)
    }


    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.notification, forKey: .notification)
        try container.encode(self.timeZone, forKey: .timeZone)

        switch self.state {
        case let .scheduled(at):
            try container.encode(at, forKey: .scheduledAt)
        case let .overdue(since):
            try container.encode(since, forKey: .scheduledAt)
        case let .completed(at, scheduled):
            try container.encode(scheduled, forKey: .scheduledAt)
            try container.encode(at, forKey: .completedAt)
        }
    }
}


extension Event: Hashable {
    public static func == (lhs: Event, rhs: Event) -> Bool {
        lhs.taskId == rhs.taskId && lhs.state == rhs.state
    }


    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(state)
    }
}
