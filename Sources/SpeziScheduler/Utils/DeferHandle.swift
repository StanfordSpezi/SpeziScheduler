//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


final class DeferHandle: Sendable {
    private let action: @Sendable () -> Void
    
    init(_ action: @Sendable @escaping () -> Void) {
        self.action = action
    }
    
    deinit {
        action()
    }
}
