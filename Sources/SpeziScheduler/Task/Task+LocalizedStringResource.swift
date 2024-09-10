//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// A type that has localized title and instructions.
public protocol _HasLocalization { // swiftlint:disable:this type_name
    /// The localization value for the title.
    var title: String.LocalizationValue { get }
    /// The localization value for the instructions.
    var instructions: String.LocalizationValue { get }
}


/// Adds LocalizedStringResource overloads for title and instructions
public protocol _LocalizedStringResourceAccessors: _HasLocalization { // swiftlint:disable:this type_name
    /// The localized title.
    @_disfavoredOverload var title: LocalizedStringResource { get }
    /// The localized instructions.
    @_disfavoredOverload var instructions: LocalizedStringResource { get }
}


extension _LocalizedStringResourceAccessors {
    /// The title as a LocalizedStringResource allowing easy integration with SwiftUI.
    public var title: LocalizedStringResource {
        LocalizedStringResource(title)
    }

    /// The instructions as a LocalizedStringResource allowing easy integration with SwiftUI.
    public var instructions: LocalizedStringResource {
        LocalizedStringResource(instructions)
    }
}


// `title` and `instructions` are of type String.LocalizationValue which the SwiftUI text initializer doesn't support.
// With this small trick we added two `title` and `instructions` property overloads with type `LocalizedStringResource`
// which can be used with several SwiftUI initializers.
extension Task: _LocalizedStringResourceAccessors {}
