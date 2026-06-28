# ``SpeziSchedulerUI``

<!--

This source file is part of the Stanford Spezi open-source project

SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT

-->

SwiftUI components for displaying scheduled tasks and events in your application.

## Overview

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

Use ``EventScheduleList`` to display all events for a specific day. It automatically handles empty states and defaults to today's date:

```swift
import SpeziSchedulerUI

struct ScheduleView: View {
    var body: some View {
        NavigationStack {
            EventScheduleList { event in
                InstructionsTile(event) {
                    event.complete()
                }
            }
            .navigationTitle("Today's Schedule")
        }
    }
}
```

Pass a `date` to display events for a different day (e.g., `EventScheduleList(date: .tomorrow)`).

### Task Cards with InstructionsTile

The ``InstructionsTile`` component provides a card interface for a single event. Use the `more` trailing closure to show a detail sheet, and `alignment` to control how the content is aligned:

```swift
struct ScheduleView: View {
    var body: some View {
        EventScheduleList { event in
            // With a detail sheet and centered alignment
            InstructionsTile(event, alignment: .center) {
                event.complete()
            } more: {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Detailed Instructions")
                        .font(.headline)
                    Text("Step-by-step guide on how to complete this task...")
                }
                .padding()
            }
        }
    }
}
```

### Customizing Task Appearance

You can customize how task categories appear in the UI using the ``SwiftUICore/View/taskCategoryAppearance(for:label:image:)`` modifier:

```swift
struct ScheduleView: View {
    var body: some View {
        EventScheduleList { event in
            InstructionsTile(event) {
                event.complete()
            }
        }
        .taskCategoryAppearance(for: .questionnaire, label: "Survey", image: .system("list.clipboard.fill"))
        .taskCategoryAppearance(for: .medication, label: "Medication", image: .system("pills.fill"))
        .taskCategoryAppearance(for: .measurement, label: "Measurement", image: .system("ruler.fill"))
    }
}
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
