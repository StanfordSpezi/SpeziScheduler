//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros


public struct UserStorageEntryMacro {}


extension UserStorageEntryMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let variableDeclaration = declaration.as(VariableDeclSyntax.self),
              let binding = variableDeclaration.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
            return [] // diagnostics are provided by the peer macro expansion
        }

        let getAccessor: AccessorDeclSyntax =
        """
        get {
        self[__Key_\(identifier).self]
        }
        """

        let setAccessor: AccessorDeclSyntax =
        """
        set {
        self[__Key_\(identifier).self] = newValue
        }
        """
        return [getAccessor, setAccessor]
    }
}


extension UserStorageEntryMacro: PeerMacro {
    public static func expansion( // swiftlint:disable:this function_body_length cyclomatic_complexity
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // TODO: update name in diagnostics!
        guard let variableDeclaration = declaration.as(VariableDeclSyntax.self) else {
            throw DiagnosticsError(syntax: declaration, message: "'@UserInfoEntry' can only be applied to a 'var' declaration", id: .invalidSyntax)
        }

        guard let binding = variableDeclaration.bindings.first,
              variableDeclaration.bindings.count == 1 else {
            throw DiagnosticsError(
                syntax: declaration,
                message: "'@UserInfoEntry' can only be applied to a 'var' declaration with a single binding",
                id: .invalidSyntax
            )
        }

        guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
            throw DiagnosticsError(
                syntax: declaration,
                message: "'@UserInfoEntry' can only be applied to a 'var' declaration with a simple name",
                id: .invalidSyntax
            )
        }

        guard let typeAnnotation = binding.typeAnnotation else {
            throw DiagnosticsError(syntax: binding, message: "Variable binding is missing a type annotation", id: .invalidSyntax)
        }

        guard let rootContext = context.lexicalContext.first,
              let extensionDecl = rootContext.as(ExtensionDeclSyntax.self) else {
            throw DiagnosticsError(
                syntax: declaration,
                message: "'@UserInfoEntry' can only be applied to 'var' declarations inside of extensions to 'Outcome' or 'ILTask.Context'",
                id: .invalidSyntax
            )
        }

        let keyProtocol: TokenSyntax

        if let identifier = extensionDecl.extendedType.as(IdentifierTypeSyntax.self)?.name.identifier,
           identifier.name == "Outcome" {
            keyProtocol = "OutcomeStorageKey"
        } else if let memberType = extensionDecl.extendedType.as(MemberTypeSyntax.self),
                  let baseIdentifier = memberType.baseType.as(IdentifierTypeSyntax.self)?.name.identifier?.name,
                  let identifier = memberType.name.identifier?.name,
                  baseIdentifier == "ILTask", // TODO: do not forget to update
                  identifier == "Context" {
            keyProtocol = "TaskStorageKey"
        } else {
            throw DiagnosticsError(
                syntax: declaration,
                message: "'@UserInfoEntry' can only be applied to 'var' declarations inside of extensions to 'Outcome' or 'ILTask.Context'",
                id: .invalidSyntax
            )
        }


        let valueTypeInitializer: TypeSyntax

        if let optionalType = typeAnnotation.type.as(OptionalTypeSyntax.self) {
            valueTypeInitializer = optionalType.wrappedType
        } else {
            // TODO: eventually support with default value?
            // valueTypeInitializer = typeAnnotation.type
            // keyProtocol = "TaskStorageKey"

            throw DiagnosticsError(syntax: binding, message: "Type annotation must use an optional type syntax", id: .invalidSyntax)
        }

        // TODO: use the default value provided!

        let modifier: TokenSyntax? = variableDeclaration.modifiers
            .compactMap { (modifier: DeclModifierSyntax) -> TokenSyntax? in
                guard case let .keyword(keyword) = modifier.name.tokenKind else {
                    return nil
                }

                switch keyword {
                case .internal, .private, .fileprivate, .public:
                    return .keyword(keyword)
                default:
                    return nil
                }
            }
            .first // there is only ever one

        let rawModifier = modifier.map { $0.text + " " } ?? ""

        let key = StructDeclSyntax(
            modifiers: modifier.map { [DeclModifierSyntax(name: $0)] } ?? [],
            name: "__Key_\(identifier)",
            inheritanceClause: InheritanceClauseSyntax(inheritedTypes: InheritedTypeListSyntax {
                InheritedTypeSyntax(type: IdentifierTypeSyntax(name: keyProtocol))
            })
        ) {
            TypeAliasDeclSyntax(
                modifiers: modifier.map { [DeclModifierSyntax(name: $0)] } ?? [],
                name: "Value",
                initializer: TypeInitializerClauseSyntax(value: valueTypeInitializer),
                trailingTrivia: .newlines(2)
            )

            """
            \(raw: rawModifier)static let identifier: String = "\(identifier)"
            """
        }

        return [
            DeclSyntax(key)
        ]
    }
}
