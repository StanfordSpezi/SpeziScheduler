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

Schedule and observe tasks for your users to complete, such as taking surveys or taking measurements.

## Overview

The Scheduler module helps you create and manage recurring tasks that users need to complete, such as daily questionnaires, medication reminders, or health measurements.

### Key Concepts

- **Task**: A repeatable action users should perform (e.g., "Take daily medication")
- **Event**: A single instance when a task should be completed (e.g., "Take medication today at 8 AM")
- **Schedule**: Defines when and how often a task repeats (e.g., daily, weekly, monthly)

The module automatically handles task persistence and versioning. When you update a task's schedule or details, it creates a new version without affecting previously completed events. This ensures your historical data remains intact.

You create tasks using `createOrUpdateTask()`, and the module takes care of generating the appropriate events based on your schedule.

### Setup

You need to add the Spezi Scheduler Swift package to
[your app in Xcode](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app) or
[Swift package](https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode#Add-a-dependency-on-another-Swift-package).

> [!IMPORTANT]  
> If your application is not yet configured to use Spezi, follow the [Spezi setup article](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/initial-setup) to set up the core Spezi infrastructure.

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

### Creating and Managing Tasks

Then, configure the [`Scheduler`](https://swiftpackageindex.com/stanfordspezi/spezischeduler/documentation/spezischeduler/scheduler) module and your custom module in your `SpeziAppDelegate`:
```swift
class ExampleAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration(standard: ExampleStandard()) {
            MySchedulerModule()
            Scheduler()
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
    category: .medication,
    schedule: .daily(hour: 8, minute: 0, startingAt: .today),
    tags: ["health", "medication", "daily"]
) { context in
    // Store additional metadata using the @Property macro
    context.about = "Take your daily medication as prescribed by your healthcare provider."
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

## User Interface Components

The `SpeziSchedulerUI` module provides ready-to-use SwiftUI components for displaying scheduled tasks and events in your app.

<table>
<tr>
<td>

![Schedule Today](Sources/SpeziSchedulerUI/SpeziSchedulerUI.docc/Resources/Schedule-Today.png#gh-light-mode-only)
![Schedule Today](Sources/SpeziSchedulerUI/SpeziSchedulerUI.docc/Resources/Schedule-Today~dark.png#gh-dark-mode-only)

*Use EventScheduleList and InstructionsTile to present the user's schedule*

</td>
<td>

![Schedule Today Center](Sources/SpeziSchedulerUI/SpeziSchedulerUI.docc/Resources/Schedule-Today-Center.png#gh-light-mode-only)
![Schedule Today Center](Sources/SpeziSchedulerUI/SpeziSchedulerUI.docc/Resources/Schedule-Today-Center~dark.png#gh-dark-mode-only)

*A schedule view with center aligned InstructionsTile*

</td>
<td>

![Schedule Tomorrow](Sources/SpeziSchedulerUI/SpeziSchedulerUI.docc/Resources/Schedule-Tomorrow.png#gh-light-mode-only)
![Schedule Tomorrow](Sources/SpeziSchedulerUI/SpeziSchedulerUI.docc/Resources/Schedule-Tomorrow~dark.png#gh-dark-mode-only)

*Use EventScheduleList to display schedules for arbitrary dates*

</td>
</tr>
</table>

### Displaying Events in Lists

Use `EventScheduleList` to display all events for a specific day. It automatically handles empty states and provides a clean, organized view of scheduled tasks:

```swift
import SpeziSchedulerUI

struct ScheduleView: View {
    var body: some View {
        NavigationStack {
            EventScheduleList { event in
                InstructionsTile(event) {
                    try event.complete()
                }
            }
            .navigationTitle("Today's Schedule")
        }
    }
}
```

You can also display events for different dates:

```swift
EventScheduleList(date: .tomorrow) { event in
    InstructionsTile(event) {
        try event.complete()
    }
}
```

### Task Cards with InstructionsTile

The `InstructionsTile` component provides a polished card interface for individual tasks:

```swift
// Basic tile with completion button
InstructionsTile(event) {
    try event.complete()
}

// Tile with additional information sheet
InstructionsTile(event) {
    try event.complete()
} more: {
    VStack(alignment: .leading, spacing: 16) {
        Text("Detailed Instructions")
            .font(.headline)
        Text("Step-by-step guide on how to complete this task...")
    }
    .padding()
}

// Centered alignment for featured tasks
InstructionsTile(event, alignment: .center) {
    try event.complete()
}
```

### Customizing Task Appearance

You can customize how different task categories appear in the UI using the `taskCategoryAppearance` modifier:

```swift
EventScheduleList { event in
    InstructionsTile(event) {
        try event.complete()
    }
}
.taskCategoryAppearance(for: .questionnaire, label: "Survey", image: .system("list.clipboard.fill"))
.taskCategoryAppearance(for: .medication, label: "Medication", image: .system("pills.fill"))
.taskCategoryAppearance(for: .measurement, label: "Measurement", image: .system("ruler.fill"))
```

### Action Buttons

For more control over task completion, use `EventActionButton` directly:

```swift
VStack {
    Text(event.task.title)
    Text(event.task.instructions)
    
    EventActionButton(event: event) {
        // Custom completion logic
        try event.complete()
        // Handle completion (e.g., show success message, update UI, etc.)
    }
}
```

You can also customize the button label:

```swift
EventActionButton(event: event, "Start Survey") {
    try event.complete()
}
```

### Connecting Real Questionnaires

To connect actual questionnaires to scheduled tasks, you can use the SpeziQuestionnaire module with FHIR-compliant questionnaire definitions. Here's the pattern used in the [SpeziTemplateApplication](https://github.com/StanfordSpezi/SpeziTemplateApplication):

#### 1. Define Questionnaire Context Property

First, extend Task.Context to store questionnaire data:

```swift
import SpeziQuestionnaire

extension Task.Context {
    @Property(coding: .json) var questionnaire: Questionnaire?
}
```

For the complete implementation, see [TemplateApplicationScheduler.swift](https://github.com/StanfordSpezi/SpeziTemplateApplication/blob/main/TemplateApplication/Schedule/TemplateApplicationScheduler.swift#L46-L48) in the SpeziTemplateApplication.

#### 2. Create Tasks with Questionnaire Context

When creating tasks, include a questionnaire context. You can load questionnaires from JSON files, create them programmatically, or fetch them from a server:

```swift
// Load questionnaire from a JSON file
guard let resourceURL = Bundle.main.url(forResource: "MoodQuestionnaire", withExtension: "json"),
      let resourceData = try? Data(contentsOf: resourceURL),
      let questionnaire = try? JSONDecoder().decode(Questionnaire.self, from: resourceData) else {
    fatalError("Could not load questionnaire")
}

try scheduler.createOrUpdateTask(
    id: "daily-mood-questionnaire",
    title: "Daily Mood Assessment",
    instructions: "Please complete your daily mood questionnaire.",
    category: .questionnaire,
    schedule: .daily(hour: 20, minute: 0, startingAt: .today)
) { context in
    context.questionnaire = questionnaire
}
```

For the complete implementation, see [TemplateApplicationScheduler.swift](https://github.com/StanfordSpezi/SpeziTemplateApplication/blob/main/TemplateApplication/Schedule/TemplateApplicationScheduler.swift#L30-L38) and [Bundle+Questionnaire.swift](https://github.com/StanfordSpezi/SpeziTemplateApplication/blob/main/TemplateApplication/Schedule/Bundle+Questionnaire.swift) in the SpeziTemplateApplication.

#### 3. Display Questionnaires in Response to Tasks

When presenting questionnaires, use the SpeziQuestionnaire module's QuestionnaireView:

```swift
import SpeziQuestionnaire

// In your view that presents the questionnaire
if let questionnaire = event.task.questionnaire {
    QuestionnaireView(questionnaire: questionnaire) { result in
        guard case let .completed(response) = result else {
            // User cancelled
            return
        }
        
        // Complete the event and store the response
        _ = try event.complete()
        await standard.add(response: response, for: questionnaire)
    }
}
```

For the complete implementation, see [EventView.swift](https://github.com/StanfordSpezi/SpeziTemplateApplication/blob/main/TemplateApplication/Schedule/EventView.swift#L25-L39) in the SpeziTemplateApplication.

#### 4. Integrate with Schedule UI

Present questionnaires when users interact with scheduled tasks:

```swift
// In your schedule view, present questionnaires as sheets
.sheet(item: $selectedEvent) { event in
    // Your questionnaire presentation view here
}
```

For a complete implementation, see [ScheduleView.swift](https://github.com/StanfordSpezi/SpeziTemplateApplication/blob/main/TemplateApplication/Schedule/ScheduleView.swift) and [EventView.swift](https://github.com/StanfordSpezi/SpeziTemplateApplication/blob/main/TemplateApplication/Schedule/EventView.swift) in the SpeziTemplateApplication.

#### 5. Handle Response Storage

Add a method to your Standard actor to store questionnaire responses:

```swift
actor MyAppStandard: Standard {
    func add(response: QuestionnaireResponse, for questionnaire: Questionnaire) async {
        // Store in your preferred data layer (Firebase, Core Data, etc.)
    }
}
```

For a complete implementation, see [TemplateApplicationStandard.swift](https://github.com/StanfordSpezi/SpeziTemplateApplication/blob/main/TemplateApplication/TemplateApplicationStandard.swift) in the SpeziTemplateApplication.

This approach provides a clean separation between task scheduling and questionnaire presentation, while leveraging FHIR standards for questionnaire definitions and responses.

For more information, please refer to the [API documentation](https://swiftpackageindex.com/StanfordSpezi/SpeziScheduler/documentation).


## The Spezi Template Application

The [Spezi Template Application](https://github.com/StanfordSpezi/SpeziTemplateApplication) provides a great starting point and example using the Spezi Scheduler module.


## Contributing

Contributions to this project are welcome. Please make sure to read the [contribution guidelines](https://github.com/StanfordSpezi/.github/blob/main/CONTRIBUTING.md) and the [contributor covenant code of conduct](https://github.com/StanfordSpezi/.github/blob/main/CODE_OF_CONDUCT.md) first.


## License

This project is licensed under the MIT License. See [Licenses](https://github.com/StanfordSpezi/SpeziScheduler/tree/main/LICENSES) for more information.

![Spezi Footer](https://raw.githubusercontent.com/StanfordSpezi/.github/main/assets/FooterLight.png#gh-light-mode-only)
![Spezi Footer](https://raw.githubusercontent.com/StanfordSpezi/.github/main/assets/FooterDark.png#gh-dark-mode-only)
