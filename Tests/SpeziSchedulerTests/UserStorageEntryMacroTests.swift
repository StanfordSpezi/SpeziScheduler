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
import SwiftSyntaxMacrosGenericTestSupport
import Testing

let testMacros: [String: any Macro.Type] = [
    "Property": UserStorageEntryMacro.self
]


@Suite
struct UserStorageEntryMacroTests { // swiftlint:disable:this type_body_length
    @Test
    func optionalProperty() {
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
            
                    static let identifier: String = "testMacro"
                    static let coding = UserStorageCoding.propertyList
                }
            }
            """,
            macros: testMacros
        )
    }
    
    
    @Test
    func optionalPropertyWithDefaultValue() {
        assertMacroExpansion(
            """
            extension Task.Context {
                @Property var testMacro: String? = "optional-default"
            }
            """,
            expandedSource:
            """
            extension Task.Context {
                var testMacro: String? {
                    get {
                        self[__Key_testMacro.self, default: "optional-default"]
                    }
                    set {
                        self[__Key_testMacro.self] = newValue
                    }
                }
            
                private struct __Key_testMacro: TaskStorageKey {
                    typealias Value = String
            
                    static let identifier: String = "testMacro"
                    static let coding = UserStorageCoding.propertyList
                }
            }
            """,
            macros: testMacros
        )
    }
    
    
    @Test
    func propertyWithDefault() {
        assertMacroExpansion(
            """
            extension Task.Context {
                @Property var testMacro: String = "default"
            }
            """,
            expandedSource:
            """
            extension Task.Context {
                var testMacro: String {
                    get {
                        self[__Key_testMacro.self, default: "default"]
                    }
                    set {
                        self[__Key_testMacro.self] = newValue
                    }
                }
            
                private struct __Key_testMacro: TaskStorageKey {
                    typealias Value = String
            
                    static let identifier: String = "testMacro"
                    static let coding = UserStorageCoding.propertyList
                }
            }
            """,
            macros: testMacros
        )
    }
    
    
    @Test
    func optionalPropertyOnOutcome() {
        assertMacroExpansion(
            """
            extension Outcome {
                @Property var testMacro: String?
            }
            """,
            expandedSource:
            """
            extension Outcome {
                var testMacro: String? {
                    get {
                        self[__Key_testMacro.self]
                    }
                    set {
                        self[__Key_testMacro.self] = newValue
                    }
                }
            
                private struct __Key_testMacro: OutcomeStorageKey {
                    typealias Value = String
            
                    static let identifier: String = "testMacro"
                    static let coding = UserStorageCoding.propertyList
                }
            }
            """,
            macros: testMacros
        )
    }
    
    
    @Test
    func publicModifier() {
        assertMacroExpansion(
            """
            extension Task.Context {
                @Property public var testMacro: String?
            }
            """,
            expandedSource:
            """
            extension Task.Context {
                public var testMacro: String? {
                    get {
                        self[__Key_testMacro.self]
                    }
                    set {
                        self[__Key_testMacro.self] = newValue
                    }
                }
            
                private struct __Key_testMacro: TaskStorageKey {
                    typealias Value = String
            
                    static let identifier: String = "testMacro"
                    static let coding = UserStorageCoding.propertyList
                }
            }
            """,
            macros: testMacros
        )
    }
    
    
    @Test
    func bindingDiagnostics() { // swiftlint:disable:this function_body_length
        assertMacroExpansion(
            """
            extension Task.Context {
                @Property var testMacro = "value"
            }
            """,
            expandedSource:
            """
            extension Task.Context {
                var testMacro {
                    get {
                        self[__Key_testMacro .self, default: "value"]
                    }
                    set {
                        self[__Key_testMacro .self] = newValue
                    }
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "Variable binding is missing a type annotation", line: 2, column: 19)
            ],
            macros: testMacros
        )

        assertMacroExpansion(
            """
            @Property
            extension Task.Context {
            }
            """,
            expandedSource:
            """
            extension Task.Context {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "'@Property' can only be applied to a 'var' declaration", line: 1, column: 1)
            ],
            macros: testMacros
        )

        assertMacroExpansion(
            """
            extension Task.Context {
                @Property var testMacro: String
            }
            """,
            expandedSource:
            """
            extension Task.Context {
                var testMacro: String {
                    get {
                        self[__Key_testMacro.self]
                    }
                    set {
                        self[__Key_testMacro.self] = newValue
                    }
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "A non-optional type requires an initializer expression to provide a default value", line: 2, column: 19)
            ],
            macros: testMacros
        )
    }
    
    
    @Test
    func lexicalContext() { // swiftlint:disable:this function_body_length
        assertMacroExpansion(
            """
            extension NotAllowed {
                @Property var testMacro: String?
            }
            """,
            expandedSource:
            """
            extension NotAllowed {
                var testMacro: String? {
                    get {
                        self[__Key_testMacro.self]
                    }
                    set {
                        self[__Key_testMacro.self] = newValue
                    }
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@Property' can only be applied to 'var' declarations inside of extensions to 'Outcome' or 'Task.Context'",
                    line: 2,
                    column: 5
                )
            ],
            macros: testMacros
        )

        assertMacroExpansion(
            """
            struct NotAllowed {
                @Property var testMacro: String?
            }
            """,
            expandedSource:
            """
            struct NotAllowed {
                var testMacro: String? {
                    get {
                        self[__Key_testMacro.self]
                    }
                    set {
                        self[__Key_testMacro.self] = newValue
                    }
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@Property' can only be applied to 'var' declarations inside of extensions to 'Outcome' or 'Task.Context'",
                    line: 2,
                    column: 5
                )
            ],
            macros: testMacros
        )
    }
    
    
    @Test
    func jsonCoding() { // swiftlint:disable:this function_body_length
        assertMacroExpansion(
            """
            extension Task.Context {
                @Property(coding: .json) var testMacro: String?
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
            
                    static let identifier: String = "testMacro"
                    static let coding = UserStorageCoding.json
                }
            }
            """,
            macros: testMacros
        )

        assertMacroExpansion(
            """
            extension Task.Context {
                @Property(coding: UserInfoCoding.json) var testMacro: String?
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
            
                    static let identifier: String = "testMacro"
                    static let coding = UserStorageCoding.json
                }
            }
            """,
            macros: testMacros
        )
    }
    
    
    @Test
    func customCoding() {
        assertMacroExpansion(
            """
            extension Task.Context {
                @Property(coding: UserInfoCoding(encoder: TestEncoder(), decoder: TestDecoder())) var testMacro: String?
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
            
                    static let identifier: String = "testMacro"
                    static let coding = UserInfoCoding(encoder: TestEncoder(), decoder: TestDecoder())
                }
            }
            """,
            macros: testMacros
        )
    }
}

#endif
