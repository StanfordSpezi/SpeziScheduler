# ``SpeziScheduler``

<!--
                  
This source file is part of the Stanford Spezi open-source project

SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT
             
-->

Schedule and observe tasks for your users to complete, such as taking surveys or taking measurements.

## Overview

The Scheduler module allows the scheduling and observation of ``Task``s adhering to a specific ``Schedule``.

A ``Task`` is an potentially repeated action or work that a user is supposed to perform. An ``Event`` represents a single
occurrence of a task, that is derived from its ``Schedule``.

You use the `Scheduler` module to manage the persistence store of your tasks. It provides a versioned, append-only store
for tasks. It allows to modify the properties (e.g., schedule) of future events without affecting occurrences of the past.

You create and automatically update your tasks
using ``Scheduler/createOrUpdateTask(id:title:instructions:category:schedule:completionPolicy:tags:effectiveFrom:with:)``.

Below is a example on how to create your own [`Module`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module)
to manage your tasks and ensure they are always up to date.

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
                category: Task.Category("Questionnaire", systemName: "list.clipboard.fill"),
                schedule: .daily(hour: 9, minute: 0, startingAt: .today)
            )
        } catch {
            // handle error (e.g., visualize in your UI)
        }
    }
}
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
