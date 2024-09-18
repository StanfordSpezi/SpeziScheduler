//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


extension SchedulerNotifications {
    /// Access the task id from the `userInfo` of a notification.
    ///
    /// The ``Task/id`` is stored in the [`userInfo`](https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent/userinfo)
    /// property of a notification. This string identifier is used as the key.
    ///
    /// ```swift
    /// let content = content.userInfo[SchedulerNotifications.notificationTaskIdKey]
    /// ```
    public static nonisolated let notificationTaskIdKey = "\(baseNotificationId).taskId"

    /// The reverse dns notation use as a prefix for all notifications scheduled by SpeziScheduler.
    static nonisolated let baseNotificationId = "edu.stanford.spezi.scheduler.notification"

    /// /// The reverse dns notation use as a prefix for all task-level scheduled notifications (calendar trigger).
    static nonisolated let baseTaskNotificationId = "\(baseNotificationId).task"

    /// /// The reverse dns notation use as a prefix for all event-level scheduled notifications (interval trigger).
    static nonisolated let baseEventNotificationId = "\(baseNotificationId).event"

    /// Retrieve the category identifier for a notification for a task, derived from its task category.
    ///
    /// This method derive the notification category from the task category. If a task has a task category set, it will be used to set the
    /// [`categoryIdentifier`](https://developer.apple.com/documentation/usernotifications/unnotificationcontent/categoryidentifier) of the
    /// notification content.
    /// By matching against the notification category, you can [Customize the Appearance of Notifications](https://developer.apple.com/documentation/usernotificationsui/customizing-the-appearance-of-notifications)
    /// or [Handle user-selected actions](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions#Handle-user-selected-actions).
    ///
    /// - Parameter category: The task category to generate the category identifier for.
    /// - Returns: The category identifier supplied in the notification content.
    public static nonisolated func notificationCategory(for category: Task.Category) -> String {
        "\(baseNotificationId).category.\(category.rawValue)"
    }

    /// The notification thread identifier for a given task.
    ///
    /// If notifications are grouped by task, this method can be used to derive the thread identifier from the task ``Task/id``.
    /// - Parameter taskId: The task identifier.
    /// - Returns: The notification thread identifier for a task.
    public static nonisolated func notificationThreadIdentifier(for taskId: String) -> String {
        "\(notificationTaskIdKey).\(taskId)"
    }

    /// The notification request identifier for a given event.
    /// - Parameter event: The event.
    /// - Returns: Returns the identifier for the notification request when creating a request for the specified event.
    public static nonisolated func notificationId(for event: Event) -> String {
        "\(baseEventNotificationId).\(event.task.id).\(event.occurrence.start)" // TODO: brint timeInterval since Reference?
    }
    
    /// The notification request identifier for a given task if its scheduled using a repeating calendar trigger.
    /// - Parameter task: The task.
    /// - Returns: Returns the identifier for the notification request when scheduling using a repeating calendar trigger.
    public static nonisolated func notificationId(for task: Task) -> String {
        "\(baseTaskNotificationId).\(task.id)"
    }
}
