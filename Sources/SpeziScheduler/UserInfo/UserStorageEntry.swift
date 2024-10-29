//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Add additional properties to an `Outcome` or `Task`.
///
/// You can use the `Property` macro to add additional, persisted properties to a ``Task`` or an ``Outcome``.
/// Your type must conform to [`Codable`](https://developer.apple.com/documentation/swift/codable) for it to be stored
/// in the SpeziScheduler data store.
///
/// - Tip: You can either declare the property as an optional type or provide a initializer expression with a default value.
///
/// ### Extending a Task
///
/// To add a new property to a task, you extend the task's ``Task/Context`` as shown in the code sample below.
///
/// ```swift
/// extension Task.Context {
///     @Property var measurementType: MeasurementType?
/// }
/// ```
///
/// ### Extending an Outcome
///
/// To add a new property to an outcome, you extend the `Outcome` type.
///
/// ```swift
/// extension Outcome {
///     @Property var measurement: WeightMeasurement?
/// }
/// ```
@attached(accessor, names: named(get), named(set))
@attached(peer, names: prefixed(__Key_))
public macro Property() = #externalMacro(module: "SpeziSchedulerMacros", type: "UserStorageEntryMacro")
