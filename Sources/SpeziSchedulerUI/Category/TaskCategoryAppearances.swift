//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziScheduler
import SpeziViews
import SwiftUI


/// Stores all configured category appearances for the view hierarchy.
public struct TaskCategoryAppearances {
    private let appearances: [Task.Category: Task.Category.Appearance]
    private let disableDefaultAppearances: Bool // for test purposes

    init() {
        self.init([:], disableDefaultAppearances: false)
    }

    init(_ appearances: [Task.Category: Task.Category.Appearance], disableDefaultAppearances: Bool) {
        self.appearances = appearances
        self.disableDefaultAppearances = disableDefaultAppearances
    }

    private func buildIntDefault(for category: Task.Category) -> Task.Category.Appearance? {
        guard !disableDefaultAppearances else {
            return nil
        }

        return switch category {
        case .questionnaire:
                .init(label: "Questionnaire", image: .system("heart.text.clipboard.fill"))
        case .measurement:
                .init(label: "Measurement", image: .system("heart.text.square.fill"))
        case .medication:
                .init(label: "Medication", image: .system("pills.circle.fill"))
        default:
            nil
        }
    }

    func inserting(_ appearance: Task.Category.Appearance, for category: Task.Category) -> Self {
        var appearances = appearances
        appearances[category] = appearance
        return TaskCategoryAppearances(appearances, disableDefaultAppearances: disableDefaultAppearances)
    }

    func disableDefaultAppearances(_ disabled: Bool = true) -> Self {
        TaskCategoryAppearances(appearances, disableDefaultAppearances: disabled)
    }

    /// Retrieve the appearance for a given category.
    /// - Parameter category: The task category.
    /// - Returns: The appearance stored for the category.
    public subscript(_ category: Task.Category) -> Task.Category.Appearance? {
        appearances[category] ?? buildIntDefault(for: category)
    }
}


extension Task.Category {
    /// Visual cues on how to render a task category to the user.
    public struct Appearance {
        /// The user-visible, localized label.
        public let label: LocalizedStringResource
        /// An optional image, that represents the category.
        public let image: ImageReference?

        init(label: LocalizedStringResource, image: ImageReference?) {
            self.label = label
            self.image = image
        }
    }
}


extension Task.Category.Appearance: Sendable, Equatable {}


extension TaskCategoryAppearances: Sendable, Equatable {}


extension EnvironmentValues {
    /// The task category appearances configured for this view hierarchy.
    @Entry public var taskCategoryAppearances: TaskCategoryAppearances = .init()
}
