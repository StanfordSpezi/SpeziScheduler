//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziScheduler


struct ExampleKey: TaskStorageKey {
    typealias Value = String
}


extension ILTask.Context {
    var example: String? {
        get {
            self[ExampleKey.self]
        }
        set {
            self[ExampleKey.self] = newValue
        }
    }
}
