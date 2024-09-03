//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziFoundation


public protocol UserInfoKey<Anchor>: KnowledgeSource where Value: Codable {
    static var identifier: String { get }
}
