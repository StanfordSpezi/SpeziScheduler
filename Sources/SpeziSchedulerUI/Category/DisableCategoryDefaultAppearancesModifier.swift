//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


struct DisableCategoryDefaultAppearancesModifier: ViewModifier { // swiftlint:disable:this type_name
    private let disabled: Bool

    @Environment(\.taskCategoryAppearances)
    private var taskCategoryAppearances

    init(disabled: Bool) {
        self.disabled = disabled
    }

    func body(content: Content) -> some View {
        content
            .environment(\.taskCategoryAppearances, taskCategoryAppearances.disableDefaultAppearances(disabled))
    }
}


extension View {
    func disableCategoryDefaultAppearances(_ disabled: Bool = true) -> some View {
        modifier(DisableCategoryDefaultAppearancesModifier(disabled: disabled))
    }
}
