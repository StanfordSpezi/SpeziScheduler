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
    ///
    /// ```swift
    /// let myCategory: Task.Category = .custom("my-category")
    /// ```
    public struct Category {
        /// The category name.
        @_spi(APISupport)
        public let rawValue: String

        /// Initialize a new category by its raw value name.
        @_spi(APISupport)
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}


extension Task.Category: Hashable, Sendable, RawRepresentable, Codable {}


extension Task.Category: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}


extension Task.Category {
    /// Questionnaire category.
    public static var questionnaire: Task.Category {
        Task.Category(rawValue: "questionnaire")
    }
    
    /// Measurement category.
    public static var measurement: Task.Category {
        Task.Category(rawValue: "measurement")
    }
    
    /// Medication Category.
    public static var medication: Task.Category {
        Task.Category(rawValue: "medication")
    }
    
    /// Create a custom category.
    /// - Parameter label: The category label.
    /// - Returns: The category instance.
    public static func custom(_ label: String) -> Task.Category {
        Task.Category(rawValue: label)
    }
}
