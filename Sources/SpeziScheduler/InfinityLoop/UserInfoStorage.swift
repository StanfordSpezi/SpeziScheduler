//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation


public protocol UserInfoKey<Anchor>: KnowledgeSource where Value: Codable {
    static var identifier: String { get }
}


struct UserInfoStorage<Anchor: RepositoryAnchor> {
    private var userInfo: [String: Data] = [:]
    private var repository: ValueRepository<Anchor>

    init() {
        self.userInfo = [:]
        self.repository = ValueRepository()
    }

    func contains<Source: UserInfoKey<Anchor>>(_ source: Source.Type) -> Bool {
        repository.contains(source) || userInfo[source.identifier] != nil
    }
}


extension UserInfoStorage { // TODO: Sendable?
    mutating func get<Source: UserInfoKey<Anchor>>(_ source: Source.Type) -> Source.Value? {
        if let value = repository.get(source) {
            return value
        }

        guard let data = userInfo[source.identifier] else {
            return nil
        }

        do {
            let decoder = PropertyListDecoder()
            let value = try decoder.decode(source.Value.self, from: data)

            userInfo.removeValue(forKey: source.identifier)
            repository.set(source, value: value)
            return value
        } catch {
            // TODO: log error!
            return nil
        }
    }

    mutating func set<Source: UserInfoKey<Anchor>>(_ source: Source.Type, value newValue: Source.Value?) {
        repository.set(source, value: newValue)
        userInfo.removeValue(forKey: source.identifier)
    }
}


extension UserInfoStorage: Codable {
    init(from decoder: any Decoder) throws {
        // TODO: does this work with SwiftData?
        self.userInfo = try [String: Data](from: decoder)
        self.repository = ValueRepository()
    }

    func encode(to encoder: any Encoder) throws {
        var userInfo = userInfo // TODO: We cannot save this updated representation :/
        for entry in repository {
            guard let key = entry.anySource as? any UserInfoKey.Type else {
                continue
            }

            let data = try key.anyEncode(entry.anyValue)
            userInfo[key.identifier] = data
            // TODO: visitor pattern from SpeziAccount?
        }

        try userInfo.encode(to: encoder)
    }
}


extension UserInfoKey {
    static var identifier: String {
        "\(Self.self)"
    }

    fileprivate static func anyEncode(_ value: Any) throws -> Data {
        guard let value = value as? Value else {
            preconditionFailure("Tried to visit \(Self.self) with value \(value) which is not of type \(Value.self)")
        }

        let encoder = PropertyListEncoder()
        return try encoder.encode(value)
    }
}
