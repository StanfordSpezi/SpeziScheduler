//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension ILTask {
    public struct Category { // TODO: make category its own model, reuse information and allow to easily migrate data!
        private let categoryLabel: String.LocalizationValue
        let systemName: String?

        /// The localized category label.
        public var label: LocalizedStringResource {
            LocalizedStringResource(categoryLabel)
        }

        public init(_ label: String.LocalizationValue, systemName: String? = nil) {
            self.categoryLabel = label
            self.systemName = systemName
        }
    }
}


extension ILTask.Category: Sendable, Equatable, Codable {}


extension ILTask.Category: ExpressibleByStringInterpolation {
    public init(stringLiteral value: String) {
        self.init(String.LocalizationValue(stringLiteral: value))
    }

    public init(stringInterpolation: String.LocalizationValue.StringInterpolation) {
        self.init(String.LocalizationValue(stringInterpolation: stringInterpolation))
    }
}
