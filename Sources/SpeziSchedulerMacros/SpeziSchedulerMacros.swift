//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros


@main
struct SpeziSchedulerMacros: CompilerPlugin {
    var providingMacros: [any Macro.Type] = [UserStorageEntryMacro.self]
}
