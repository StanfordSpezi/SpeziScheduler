# ``SpeziScheduler``

<!--
                  
This source file is part of the Stanford Spezi open-source project

SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT
             
-->

Allows you to schedule and observe tasks for your users to complete, such as taking surveys.

## Overview

The Scheduler module allows the scheduling and observation of ``Task``s adhering to a specific ``Schedule``.

### Old Scheduling A Task article

The Scheduler module can be used to create and schedule tasks for your users to complete.

In the following example, we will create a task for a survey to be taken daily, starting now, for 7 days.

```swift
let surveyTask = Task(
    title: "Survey",
    description: "Take a survey",
    schedule: Schedule(
        start: .now,
        repetition: .matching(.init(day: 1)), // daily
        end: .numberOfEvents(7)
    ),
    context: "This is a test context"
)
```

The ``Schedule`` type also allows the customization of the repetition using the ``Schedule/Repetition-swift.enum`` type including the randomization
between two date components, and the definition of the end of the schedule using the ``Schedule/End-swift.enum`` type.


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
- ``Task/Category-swift.struct``
- ``Event``
- ``Outcome``
- ``Property()``

### Date Accessors

- ``Foundation/Date/today``
- ``Foundation/Date/tomorrow``
- ``Foundation/Date/yesterday``
