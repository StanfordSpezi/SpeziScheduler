# Scheduling A Task

<!--
                  
This source file is part of the Stanford Spezi open-source project

SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT
             
-->

Create and schedule a task.

## Overview

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

The ``Schedule`` type also allows the customization of the repeition using the ``Schedule/Repetition-swift.enum`` type including the randomization between two date components, and the definition of the end of the schedule using the ``Schedule/End-swift.enum`` type.

## Topics

### Components

- ``Schedule``
- ``Task``
