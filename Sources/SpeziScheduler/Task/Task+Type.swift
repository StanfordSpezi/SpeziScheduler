//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftData


extension Task {
    /// User-visible category information of a task.
    @Model
    public final class Category {
        // TODO: we should build infrastructure around category creation, if we want to keep it as a model!
        //  => maybe just an approach, where you create an category identifier and associate all the data at runtime, no need to persists visuals!
        var categoryLabel: String.LocalizationValue
        var systemName: String?

        /// The localized category label.
        public var label: LocalizedStringResource {
            LocalizedStringResource(categoryLabel)
        }

        
        /// Create a new category.
        /// - Parameters:
        ///   - label: The localized label for the category.
        ///   - systemName: An optional system image that represents the category.
        public init(_ label: String.LocalizationValue, systemName: String? = nil) { // TODO: how to support regular images
            self.categoryLabel = label
            self.systemName = systemName
        }
    }
}


extension Task.Category: Equatable {}


extension Task.Category: ExpressibleByStringInterpolation {
    public convenience init(stringLiteral value: String) {
        self.init(String.LocalizationValue(stringLiteral: value))
    }

    public convenience init(stringInterpolation: String.LocalizationValue.StringInterpolation) {
        self.init(String.LocalizationValue(stringInterpolation: stringInterpolation))
    }
}
