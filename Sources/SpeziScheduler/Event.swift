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
public final class Event: Codable, Identifiable, Hashable, @unchecked Sendable {
    enum CodingKeys: String, CodingKey {
        // We use the underscore as the corresponding property `_scheduledAt` uses an underscore as it is a private property.
        // swiftlint:disable:next identifier_name
        case _scheduledAt = "scheduledAt"
        case notification
        case completedAt
    }
    
    
    private let lock = Lock()
    private let timer: Timer? = nil
    private let _scheduledAt: Date
    private var notification: UUID?
    /// The date when the ``Event`` was completed.
    public private(set) var completedAt: Date?
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
    
    
    func scheduleTaskAndNotification() {
        guard let taskReference = taskReference else {
            return
        }
        
        // Schedule the timer for the event that refreshes the Observable Object.
        if timer == nil {
            let scheduledTimer = Timer(
                timeInterval: max(Date.now.distance(to: scheduledAt), 0.01),
                repeats: false,
                block: { timer in
                    timer.invalidate()
                    taskReference.sendObjectWillChange()
                }
            )
            
            RunLoop.current.add(scheduledTimer, forMode: .common)
        }
        
        // Only schedule a notification if it is enabled in a task and the notification has not yet been scheduled.
        if taskReference.notifications && notification == nil {
            _Concurrency.Task {
                let notificationCenter = UNUserNotificationCenter.current()
                let authorizationStatus = await notificationCenter.notificationSettings().authorizationStatus
                switch authorizationStatus {
                case .notDetermined, .denied:
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
                    
                    try await notificationCenter.add(request)
                    
                    self.notification = identifier
                }
            }
        }
    }
    
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(taskReference?.id)
        hasher.combine(_scheduledAt)
    }
    
    /// Use this function to mark an ``Event`` as complete or incomplete.
    /// - Parameter newValue: The new state of the ``Event``.
    public func complete(_ newValue: Bool) async {
        await lock.enter {
            if newValue {
                completedAt = Date()
            } else {
                completedAt = nil
            }
            taskReference?.sendObjectWillChange()
        }
    }
    
    
    /// Toggle the ``Event``'s ``Event/complete`` state.
    public func toggle() async {
        await complete(!complete)
    }
    
    
    deinit {
        timer?.invalidate()
    }
}
