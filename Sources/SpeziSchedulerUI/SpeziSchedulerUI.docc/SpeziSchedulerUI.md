# ``SpeziSchedulerUI``

<!--

This source file is part of the Stanford Spezi open-source project

SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT

-->

UI components provided for SpeziScheduler.

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
