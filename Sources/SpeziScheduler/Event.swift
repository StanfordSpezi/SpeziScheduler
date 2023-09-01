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


/// An  ``Event`` describes a unique point in time when a ``Task`` is scheduled. Use events to display the recurring nature of a ``Task`` to a user.
///
/// Use the  ``Event/complete(_:)`` and ``Event/toggle()`` functions to mark an Event as complete. You can access the scheduled date of an
/// event using ``Event/scheduledAt`` and the completed date using the ``Event/completedAt`` properties.
public final class Event: Codable, Identifiable, Hashable, @unchecked Sendable {
    enum CodingKeys: String, CodingKey {
        // We use the underscore as the corresponding property `_scheduledAt` uses an underscore as it is a private property.
        // swiftlint:disable:next identifier_name
        case _scheduledAt = "scheduledAt"
        case notification
        case completedAt
    }
    
    
    private let lock = Lock()
    private var timer: Timer?
    private let _scheduledAt: Date
    private(set) var notification: UUID?
    /// The date when the ``Event`` was completed.
    public private(set) var completedAt: Date? {
        didSet {
            guard completedAt != oldValue else {
                return
            }
            
            taskReference?.sendObjectWillChange()
        }
    }
    /// Only used for test purposes to identify the current state of the log in the UI testing application.
    internal private(set) var log: String?
    weak var taskReference: (any TaskReference)?
    
    
    /// The date when the ``Event`` is scheduled at.
    public var scheduledAt: Date {
        guard let taskReference = taskReference else {
            return _scheduledAt
        }
        
        let timeZoneDifference = TimeInterval(
            taskReference.schedule.calendar.timeZone.secondsFromGMT(for: .now) - Calendar.current.timeZone.secondsFromGMT(for: .now)
        )
        return _scheduledAt.addingTimeInterval(timeZoneDifference)
    }
    
    /// Indictes if the ``Event`` is complete.
    public var complete: Bool {
        completedAt != nil
    }
    
    public var id: String {
        "\(taskReference?.id.uuidString ?? "").\(_scheduledAt.description)"
    }
    
    
    init(scheduledAt: Date, eventsContainer: any TaskReference) {
        self._scheduledAt = scheduledAt
        self.taskReference = eventsContainer
    }
    
    
    public static func == (lhs: Event, rhs: Event) -> Bool {
        lhs.taskReference?.id == rhs.taskReference?.id && lhs.scheduledAt == rhs.scheduledAt
    }
    
    
    /// Use this function to mark an ``Event`` as complete or incomplete.
    /// - Parameter newValue: The new state of the ``Event``.
    public func complete(_ newValue: Bool) async {
        await lock.enter {
            if newValue {
                completedAt = Date()
                if let notification {
                    let notificationCenter = UNUserNotificationCenter.current()
                    notificationCenter.removeDeliveredNotifications(withIdentifiers: [notification.uuidString])
                    notificationCenter.removePendingNotificationRequests(withIdentifiers: [notification.uuidString])
                }
            } else {
                completedAt = nil
            }
        }
    }
    
    /// Toggle the ``Event``'s ``Event/complete`` state.
    public func toggle() async {
        await complete(!complete)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(taskReference?.id)
        hasher.combine(_scheduledAt)
    }
    
    
    func cancelNotification() {
        guard let notification else {
            return
        }
        
        guard complete || scheduledAt > .now else {
            self.log = "Notification Delivered - Not yet Completed"
            return
        }
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [notification.uuidString])
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notification.uuidString])
        
        self.notification = nil
        self.log = "No Notification - Complete: \(complete)"
    }
    
    func scheduleTask() {
        guard let taskReference = taskReference else {
            return
        }
        
        // Schedule the timer for the event that refreshes the Observable Object.
        if timer == nil {
            timer = Timer(
                timeInterval: max(Date.now.distance(to: scheduledAt), .leastNonzeroMagnitude),
                repeats: false,
                block: { timer in
                    timer.invalidate()
                    taskReference.sendObjectWillChange()
                }
            )
            
            if let timer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }
    
    func scheduleNotification() async {
        guard let taskReference = taskReference else {
            return
        }
        
        // Only schedule a notification if it is enabled in a task and the notification has not yet been scheduled.
        if taskReference.notifications && notification == nil {
            let notificationCenter = UNUserNotificationCenter.current()
            switch await notificationCenter.notificationSettings().authorizationStatus {
            case .notDetermined, .denied:
                self.log = "Could not register due to missing permissions ..."
                return
            default:
                let content = UNMutableNotificationContent()
                content.title = taskReference.title
                content.body = taskReference.description
                
                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: max(self.scheduledAt.timeIntervalSince(.now), TimeInterval.leastNonzeroMagnitude),
                    repeats: false
                )
                
                let identifier = UUID()
                let request = UNNotificationRequest(identifier: identifier.uuidString, content: content, trigger: trigger)
                
                do {
                    try await notificationCenter.add(request)
                    self.log = "Registered at \(self.scheduledAt.formatted(date: .abbreviated, time: .complete))"
                    self.notification = identifier
                } catch {
                    os_log(.error, "Spezi.Scheduler: Could not schedule task as local notification: \(error)")
                    self.log = "Could not schedule task as local notification: \(error)"
                }
            }
        }
    }
    
    
    deinit {
        timer?.invalidate()
    }
}
