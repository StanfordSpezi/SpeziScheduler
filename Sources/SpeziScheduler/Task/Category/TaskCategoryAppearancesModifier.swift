//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziViews
import SwiftUI


private struct TaskCategoryAppearancesModifier: ViewModifier {
    private let category: Task.Category
    private let appearance: Task.Category.Appearance

    @Environment(\.taskCategoryAppearances)
    private var appearances


    init(category: Task.Category, appearance: Task.Category.Appearance) {
        self.category = category
        self.appearance = appearance
    }

    func body(content: Content) -> some View {
        content
            .environment(\.taskCategoryAppearances, appearances.inserting(appearance, for: category))
    }
}


extension View {
    /// Define a new appearance for a task category.
    /// - Parameters:
    ///   - category: The task category to define a new appearance for.
    ///   - label: The user-visible, localized label that refers to the category.
    ///   - image: An optional image resource that refers to the category.
    /// - Returns: Returns the modified view, with the specified entry added to the ``TaskCategoryAppearances`` storage.
    public func taskCategoryAppearance(for category: Task.Category, label: LocalizedStringResource, image: ImageReference? = nil) -> some View {
        modifier(TaskCategoryAppearancesModifier(category: category, appearance: .init(label: label, image: image)))
    }
}
