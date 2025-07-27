//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziScheduler
import SpeziViews
import SwiftUI


private struct TaskCategoryAppearancesModifier: ViewModifier {
    let provider: TaskCategoryAppearances.AppearanceProvider

    @Environment(\.taskCategoryAppearances)
    private var appearances

    func body(content: Content) -> some View {
        content
            .environment(\.taskCategoryAppearances, appearances.appending(provider))
    }
}


extension View {
    /// Specify the appearance to be used for a task category.
    /// - Parameters:
    ///   - category: The task category to define a new appearance for.
    ///   - label: The user-visible, localized label that refers to the category.
    ///   - image: An optional image resource that refers to the category.
    /// - Returns: Returns the modified view, with the specified entry added to the ``SwiftUICore/EnvironmentValues/taskCategoryAppearances`` storage.
    ///
    /// - Note: Appearance definitions are processed in reverse order of how they are applied to a View; later appearances take precedence over earlier ones.
    public func taskCategoryAppearance(for category: Task.Category, label: LocalizedStringResource, image: ImageReference? = nil) -> some View {
        self.taskCategoryAppearance {
            $0 == category ? .init(label: label, image: image) : nil
        }
    }
    
    /// Provide appearances for task categories.
    ///
    /// - parameter provider: A closure that maps a task category to an appearance definition.
    ///
    /// - Note: Appearance definitions are processed in reverse order of how they are applied to a View; later appearances take precedence over earlier ones.
    ///     The first task category appearance provider that returns a nonnil value defines the task's appearance.
    public func taskCategoryAppearance(_ provider: @escaping @Sendable (Task.Category) -> Task.Category.Appearance?) -> some View {
        modifier(TaskCategoryAppearancesModifier(provider: provider))
    }
}
