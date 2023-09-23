//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


protocol TaskReference: AnyObject {
    var id: UUID { get }
    var title: String { get }
    var schedule: Schedule { get }
    var notifications: Bool { get }
    
    
    func sendObjectWillChange()
}
