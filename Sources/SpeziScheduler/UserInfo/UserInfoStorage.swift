//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

#if canImport(Darwin)
import Foundation
import SpeziFoundation


/// Property lists can never store single values (unlike JSON). Therefore, we always embed values into a container.
private struct SingleValueWrapper<Value: Codable>: Codable {
    let value: Value

    init(value: Value) {
        self.value = value
    }
}

@_spi(APISupport)
public struct UserInfoStorage<Anchor: RepositoryAnchor>: Codable {
    struct RepositoryCache {
        var repository = ValueRepository<Anchor>()
    }

    private(set) var userInfo: [String: Data] = [:]

    init() {
        self.userInfo = [:]
    }

    func contains<Source: _UserInfoKey<Anchor>>(_ source: Source.Type) -> Bool {
        userInfo[source.identifier] != nil
    }
}


extension UserInfoStorage {
    func get<Source: _UserInfoKey<Anchor>>(
        _ source: Source.Type,
        cache: inout RepositoryCache
    ) throws -> Source.Value? {
        if let value = cache.repository.get(source) {
            return value
        }
        guard let data = userInfo[source.identifier] else {
            return nil
        }
        let decoder = source.coding.decoder
        let value = try decoder.decode(SingleValueWrapper<Source.Value>.self, from: data)
        cache.repository.set(source, value: value.value)
        return value.value
    }

    mutating func set<Source: _UserInfoKey<Anchor>>(
        _ source: Source.Type,
        value newValue: Source.Value?,
        cache: inout RepositoryCache
    ) throws {
        cache.repository.set(source, value: newValue)
        if let newValue {
            let encoder = source.coding.encoder
            userInfo[source.identifier] = try encoder.encode(SingleValueWrapper(value: newValue))
        } else {
            userInfo.removeValue(forKey: source.identifier)
        }
    }
}


extension UserInfoStorage: Equatable {
    public static func == (lhs: UserInfoStorage<Anchor>, rhs: UserInfoStorage<Anchor>) -> Bool {
        lhs.userInfo == rhs.userInfo
    }
}


extension UserInfoStorage: CustomStringConvertible {
    public var description: String {
        "UserInfoStorage(\(userInfo.keys.joined(separator: ", ")))"
    }
}
#endif
