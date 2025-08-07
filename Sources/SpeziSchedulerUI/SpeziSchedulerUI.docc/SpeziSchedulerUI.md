# ``SpeziSchedulerUI``

<!--

This source file is part of the Stanford Spezi open-source project

SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT

-->

Ready-to-use SwiftUI components for displaying scheduled tasks and events in your app.

## Overview

The `SpeziSchedulerUI` module provides polished UI components that automatically connect to your configured `Scheduler` instance to display tasks and handle user interactions.

@Row {
    @Column {
        @Image(source: "Schedule-Today", alt: "A schedule view showing a upcoming Task at 4pm to complete the Social Support Questionnaire.") {
            Use the ``EventScheduleList`` and the ``InstructionsTile`` to present the user's schedule.
        }
    }
    @Column {
        @Image(source: "Schedule-Today-Center", alt: "A schedule view with center alignment showing a upcoming Task at 4pm to complete the Social Support Questionnaire.") {
            A schedule view with a `center` aligned ``InstructionsTile``.
        }
    }
    @Column {
        @Image(source: "Schedule-Tomorrow", alt: "A schedule view showing a upcoming Task for tomorrow.") {
            Use the ``EventScheduleList`` view to display the schedule for arbitrary dates.
        }
    }
}

### Displaying Events in Lists

Use ``EventScheduleList`` to display all events for a specific day. It automatically handles empty states and provides a clean, organized view of scheduled tasks:

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

The ``InstructionsTile`` component provides a polished card interface for individual tasks:

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

You can customize how different task categories appear in the UI using the `taskCategoryAppearance(for:label:image:)` modifier:

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


## Topics

### Card Layouts

- ``InstructionsTile``
- ``DefaultTileHeader``
- ``EventActionButton``

### Displaying Events

- ``EventScheduleList``

### Category Appearance
Control how the category information of a task should be rendered to the user.

- ``SpeziScheduler/Task/Category/Appearance``
- ``SwiftUICore/View/taskCategoryAppearance(for:label:image:)``
- ``SwiftUICore/EnvironmentValues/taskCategoryAppearances``
- ``TaskCategoryAppearances``
