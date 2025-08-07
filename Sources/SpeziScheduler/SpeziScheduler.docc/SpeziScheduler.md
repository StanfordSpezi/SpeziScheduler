# ``SpeziScheduler``

<!--
                  
This source file is part of the Stanford Spezi open-source project

SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT
             
-->

Schedule and observe tasks for your users to complete, such as taking surveys or taking measurements.

## Overview

The Scheduler module helps you create and manage recurring tasks that users need to complete, such as daily questionnaires, medication reminders, or health measurements.

### Key Concepts

- **Task**: A repeatable action users should perform (e.g., "Take daily medication")
- **Event**: A single instance when a task should be completed (e.g., "Take medication today at 8 AM")
- **Schedule**: Defines when and how often a task repeats (e.g., daily, weekly, monthly)

The module automatically handles task persistence and versioning. When you update a task's schedule or details, it creates a new version without affecting previously completed events. This ensures your historical data remains intact.

You create tasks using ``Scheduler/createOrUpdateTask(id:title:instructions:category:schedule:completionPolicy:tags:effectiveFrom:with:)``, and the module takes care of generating the appropriate events based on your schedule.

Below is an example on how to create your own [`Module`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module) to manage your tasks and ensure they are always up to date.

```swift
import Spezi
import SpeziScheduler

class MySchedulerModule: Module {
    @Dependency(Scheduler.self)
    private var scheduler

    init() {}

    func configure() {
        do {
            try scheduler.createOrUpdateTask(
                id: "my-daily-task",
                title: "Daily Questionnaire",
                instructions: "Please fill out the Questionnaire every day.",
                category: .questionnaire,
                schedule: .daily(hour: 9, minute: 0, startingAt: .today)
            )
        } catch {
            // handle error (e.g., visualize in your UI)
        }
    }
}
```

### Task Scheduling Options

The Scheduler supports various scheduling patterns using the ``Schedule`` type:

```swift
// One-time task
let onceSchedule = Schedule.once(at: Date(), duration: .tillEndOfDay)

// Daily tasks
let dailySchedule = Schedule.daily(hour: 8, minute: 30, startingAt: .today)

// Weekly tasks
let weeklySchedule = Schedule.weekly(
    weekday: .monday, 
    hour: 10, 
    minute: 0, 
    startingAt: .today
)

// Monthly tasks
let monthlySchedule = Schedule.monthly(
    day: 1, 
    hour: 9, 
    minute: 0, 
    startingAt: .today
)

// Custom recurrence patterns
var customRule = Calendar.RecurrenceRule.weekly(calendar: .current, end: .never)
customRule.weekdays = [.every(.monday), .every(.wednesday), .every(.friday)]
let customSchedule = Schedule(startingAt: .today, recurrence: customRule)
```

### Notifications

The Scheduler can automatically schedule notifications for upcoming tasks. First, ensure your `Standard` conforms to the ``SchedulerNotificationsConstraint`` protocol:

```swift
actor ExampleStandard: Standard, SchedulerNotificationsConstraint {
    @MainActor
    func notificationContent(for task: borrowing Task, content: borrowing UNMutableNotificationContent) {
        // Customize notification content if needed
    }
}
```

Then configure the ``SchedulerNotifications`` module and enable notifications for specific tasks:

```swift
try scheduler.createOrUpdateTask(
    id: "reminder-task",
    title: "Daily Check-in",
    instructions: "Complete your daily check-in.",
    schedule: .daily(hour: 18, minute: 0, startingAt: .today),
    scheduleNotifications: true
)
```

## Topics

### Scheduler
- ``Scheduler``
- ``EventQuery``
- ``Scheduler/DataError``

### Schedule

- ``Schedule``
- ``Schedule/Duration-swift.enum``
- ``Occurrence``

### Task

- ``Task``
- ``Task/ID-swift.struct``
- ``Task/Category-swift.struct``
- ``Event``
- ``Outcome``
- ``Property(coding:)``
- ``AllowedCompletionPolicy``

### Notifications

- ``SchedulerNotifications``
- ``SchedulerNotificationsConstraint``
- ``NotificationTime``
- ``NotificationThread``

### Date Extensions

- ``Foundation/Date/today``
- ``Foundation/Date/tomorrow``
- ``Foundation/Date/yesterday``
- ``Foundation/Date/nextWeek``
