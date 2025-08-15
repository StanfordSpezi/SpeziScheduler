//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension FileManager {
    func itemExists(at url: URL) -> Bool {
        self.fileExists(atPath: url.absoluteURL.path)
    }
    
    func createFile(
        at url: URL,
        contents: Data?,
        attributes: [FileAttributeKey: Any]? = nil // swiftlint:disable:this discouraged_optional_collection
    ) -> Bool {
        self.createFile(atPath: url.absoluteURL.path, contents: contents, attributes: attributes)
    }
}
