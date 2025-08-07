<!--

This source file is part of the Stanford Spezi open-source project.

SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT
  
-->

# Spezi Scheduler

[![Build and Test](https://github.com/StanfordSpezi/SpeziScheduler/actions/workflows/build-and-test.yml/badge.svg)](https://github.com/StanfordSpezi/SpeziScheduler/actions/workflows/build-and-test.yml)
[![codecov](https://codecov.io/gh/StanfordSpezi/SpeziScheduler/branch/main/graph/badge.svg?token=0SRI67ItFw)](https://codecov.io/gh/StanfordSpezi/SpeziScheduler)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.7706954.svg)](https://doi.org/10.5281/zenodo.7706954)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FStanfordSpezi%2FSpeziScheduler%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/StanfordSpezi/SpeziScheduler)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FStanfordSpezi%2FSpeziScheduler%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/StanfordSpezi/SpeziScheduler)

Schedule and manage recurring tasks in your Spezi app.

## Overview

The Spezi Scheduler module enables apps to create, schedule, and manage recurring tasks with flexible scheduling options. Tasks can represent any repeatable action a user should perform, such as questionnaires, measurements, or medication reminders. The module provides comprehensive support for notifications, task versioning, and outcome tracking.

### Setup

You need to add the Spezi Scheduler Swift package to
[your app in Xcode](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app) or
[Swift package](https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode#Add-a-dependency-on-another-Swift-package).

> [!IMPORTANT]  
> If your application is not yet configured to use Spezi, follow the [Spezi setup article](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/initial-setup) to set up the core Spezi infrastructure.

### Creating and Managing Tasks

You can create and manage tasks by setting up a custom [`Module`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module) that uses the [`Scheduler`](https://swiftpackageindex.com/stanfordspezi/spezischeduler/documentation/spezischeduler/scheduler) module. The module ensures tasks are automatically created and kept up to date.

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
                id: "daily-questionnaire",
                title: "Daily Questionnaire",
                instructions: "Please fill out the daily questionnaire.",
                category: Task.Category("Questionnaire", systemName: "list.clipboard.fill"),
                schedule: .daily(hour: 9, minute: 0, startingAt: .today)
            )
        } catch {
            // handle error (e.g., visualize in your UI)
        }
    }
}
```

Then, configure the [`Scheduler`](https://swiftpackageindex.com/stanfordspezi/spezischeduler/documentation/spezischeduler/scheduler) module and your custom module in your `SpeziAppDelegate`:
```swift
class ExampleAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration(standard: ExampleStandard()) {
            Scheduler()
            MySchedulerModule()
        }
    }
}
```

### Task Scheduling Options

The Scheduler supports various scheduling patterns using the [`Schedule`](https://swiftpackageindex.com/stanfordspezi/spezischeduler/documentation/spezischeduler/schedule) type:

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

### Task Categories and Metadata

Tasks can include categories and additional metadata for better organization and functionality:

```swift
try scheduler.createOrUpdateTask(
    id: "medication-reminder",
    title: "Morning Medication",
    instructions: "Take your prescribed morning medication with water.",
    category: Task.Category("Medication", systemName: "pills.fill"),
    schedule: .daily(hour: 8, minute: 0, startingAt: .today),
    tags: ["health", "medication", "daily"]
) { context in
    // Store additional metadata
    context.medicationType = .prescription
    context.dosage = "10mg"
}
```

### Notifications

The Scheduler can automatically schedule notifications for upcoming tasks. First, ensure your `Standard` conforms to the [`SchedulerNotificationsConstraint`](https://swiftpackageindex.com/stanfordspezi/spezischeduler/documentation/spezischeduler/schedulernotificationsconstraint) protocol:

```swift
actor ExampleStandard: Standard, SchedulerNotificationsConstraint {
    @MainActor
    func notificationContent(for task: borrowing Task, content: borrowing UNMutableNotificationContent) {
        // Customize notification content if needed
    }
}
```

Then configure the [`SchedulerNotifications`](https://swiftpackageindex.com/stanfordspezi/spezischeduler/documentation/spezischeduler/schedulernotifications) module and enable notifications for specific tasks:

```swift
class ExampleAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration(standard: ExampleStandard()) {
            Scheduler()
            SchedulerNotifications()
            MySchedulerModule()
        }
    }
}

// In your task creation
try scheduler.createOrUpdateTask(
    id: "reminder-task",
    title: "Daily Check-in",
    instructions: "Complete your daily check-in.",
    schedule: .daily(hour: 18, minute: 0, startingAt: .today),
    scheduleNotifications: true
)
```

### Querying Tasks and Events

You can query tasks and events using various methods:

```swift
// Query tasks for a specific date range
let tasks = try scheduler.queryTasks(for: Date()..<Calendar.current.date(byAdding: .day, value: 7, to: Date())!)

// Query events (task occurrences) for today
let todayEvents = try scheduler.queryEvents(for: Date()..<Calendar.current.date(byAdding: .day, value: 1, to: Date())!)

// Query events for a specific task
let taskEvents = try scheduler.queryEvents(forTaskWithId: "daily-questionnaire", in: Date()..<Date().addingTimeInterval(86400))
```

For more information, please refer to the [API documentation](https://swiftpackageindex.com/StanfordSpezi/SpeziScheduler/documentation).


## The Spezi Template Application

The [Spezi Template Application](https://github.com/StanfordSpezi/SpeziTemplateApplication) provides a great starting point and example using the Spezi Scheduler module.


## Contributing

Contributions to this project are welcome. Please make sure to read the [contribution guidelines](https://github.com/StanfordSpezi/.github/blob/main/CONTRIBUTING.md) and the [contributor covenant code of conduct](https://github.com/StanfordSpezi/.github/blob/main/CODE_OF_CONDUCT.md) first.


## License

This project is licensed under the MIT License. See [Licenses](https://github.com/StanfordSpezi/SpeziScheduler/tree/main/LICENSES) for more information.

![Spezi Footer](https://raw.githubusercontent.com/StanfordSpezi/.github/main/assets/FooterLight.png#gh-light-mode-only)
![Spezi Footer](https://raw.githubusercontent.com/StanfordSpezi/.github/main/assets/FooterDark.png#gh-dark-mode-only)
