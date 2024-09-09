//
// This source file is part of the Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

#if os(macOS) // macro tests can only be run on the host machine

import SpeziSchedulerMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

let testMacros: [String: any Macro.Type] = [
    "TestMacro": UserStorageEntryMacro.self // TODO: update name!
]


final class UserStorageEntryMacroTests: XCTestCase {
    func testExampleMacro() {
        assertMacroExpansion(
            """
            extension ILTask.Context {
                @TestMacro var testMacro: String?
            }
            """,
            expandedSource:
            """
            
            """,
            macros: testMacros
        )
    }
}

#endif
