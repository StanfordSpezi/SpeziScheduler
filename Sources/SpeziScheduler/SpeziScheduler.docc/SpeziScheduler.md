# ``SpeziScheduler``

<!--
                  
This source file is part of the Stanford Spezi open-source project

SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT
             
-->

Schedule and observe tasks for your users to complete, such as taking surveys or taking measurements.

## Overview

The Scheduler module helps you create and manage recurring tasks that users need to complete, such as daily questionnaires, medication reminders, or health measurements. It can also be used for internal application logic and automated processes.

### Key Concepts

- **Task**: A repeatable action or piece of work the user should perform (e.g., "Fill out a questionnaire.")
- **Schedule**: Defines when and how often a task repeats (e.g., daily, weekly, monthly)
- **Event**: A single occurrence of a task, derived from the task and its schedule (e.g., "Fill out a questionnaire today at 8 AM")

The module automatically handles task persistence and versioning. When you update a task's schedule or details, it creates a new version without affecting previously completed events. This ensures your historical data remains intact.

You create tasks using ``Scheduler/createOrUpdateTask(id:title:instructions:category:schedule:completionPolicy:scheduleNotifications:notificationThread:notificationTime:tags:effectiveFrom:shadowedOutcomesHandling:with:)``, and the module takes care of generating the appropriate events based on your schedule.

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

The Scheduler supports various scheduling patterns using the ``Schedule`` type, including one-time, daily, weekly, and monthly schedules, as well as fully custom recurrence patterns using `Calendar.RecurrenceRule`. See the ``Schedule`` documentation for the full API.

### Notifications

To send a notification for each scheduled event, pass `scheduleNotifications: true` to ``Scheduler/createOrUpdateTask(id:title:instructions:category:schedule:completionPolicy:scheduleNotifications:notificationThread:notificationTime:tags:effectiveFrom:shadowedOutcomesHandling:with:)``. For advanced notification features, see ``SchedulerNotifications``.

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
