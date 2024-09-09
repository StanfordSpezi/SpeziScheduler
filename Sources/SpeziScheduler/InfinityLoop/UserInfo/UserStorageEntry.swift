//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


@attached(accessor, names: named(get), named(set))
@attached(peer, names: prefixed(__Key_))
public macro UserStorageEntry() = #externalMacro(module: "SpeziSchedulerMacros", type: "UserStorageEntryMacro")
// TODO: we need a better name for the macro!
