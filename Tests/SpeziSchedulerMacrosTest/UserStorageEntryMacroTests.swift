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
    "Property": UserStorageEntryMacro.self
]


final class UserStorageEntryMacroTests: XCTestCase {
    func testExampleMacro() {
        assertMacroExpansion(
            """
            extension Task.Context {
                @Property var testMacro: String?
            }
            """,
            expandedSource:
            """
            extension Task.Context {
                var testMacro: String? {
                    get {
                        self[__Key_testMacro.self]
                    }
                    set {
                        self[__Key_testMacro.self] = newValue
                    }
                }
            
                private struct __Key_testMacro: TaskStorageKey {
                    typealias Value = String
                }
            }
            """,
            macros: testMacros
        )
    }
}

#endif
