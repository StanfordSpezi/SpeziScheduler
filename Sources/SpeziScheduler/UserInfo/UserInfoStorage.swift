//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OSLog
import SpeziFoundation


/// Property lists can never store single values (unlike JSON). Therefore, we always embed values into a container.
struct SingleValueWrapper<Value: Codable>: Codable {
    let value: Value

    init(value: Value) {
        self.value = value
    }
}


struct UserInfoStorage<Anchor: RepositoryAnchor> {
    struct RepositoryCache {
        var repository = ValueRepository<Anchor>()
    }

    private var userInfo: [String: Data] = [:]

    private var logger: Logger {
        Logger(subsystem: "edu.stanford.spezi.scheduler", category: "\(Self.self)")
    }

    init() {
        self.userInfo = [:]
    }

    func contains<Source: _UserInfoKey<Anchor>>(_ source: Source.Type) -> Bool {
        userInfo[source.identifier] != nil
    }
}


extension UserInfoStorage {
    func get<Source: _UserInfoKey<Anchor>>(_ source: Source.Type, cache: inout RepositoryCache) -> Source.Value? {
        if let value = cache.repository.get(source) {
            return value
        }

        guard let data = userInfo[source.identifier] else {
            return nil
        }

        do {
            let decoder = PropertyListDecoder()
            let value = try decoder.decode(SingleValueWrapper<Source.Value>.self, from: data)

            cache.repository.set(source, value: value.value)
            return value.value
        } catch {
            logger.error("Failed to decode userInfo value for \(source) from data \(data): \(error)")
            return nil
        }
    }

    mutating func set<Source: _UserInfoKey<Anchor>>(_ source: Source.Type, value newValue: Source.Value?, cache: inout RepositoryCache) {
        cache.repository.set(source, value: newValue)

        if let newValue {
            do {
                userInfo[source.identifier] = try PropertyListEncoder().encode(SingleValueWrapper(value: newValue))
            } catch {
                logger.error("Failed to encode userInfo value \(String(describing: newValue)) for \(source): \(error)")
            }
        } else {
            userInfo.removeValue(forKey: source.identifier)
        }
    }
}


extension UserInfoStorage: RawRepresentable {
    var rawValue: [String: Data] {
        userInfo
    }

    init(rawValue: [String: Data]) {
        self.userInfo = rawValue
    }
}

extension UserInfoStorage: Codable {}


extension UserInfoStorage: Equatable {
    static func == (lhs: UserInfoStorage<Anchor>, rhs: UserInfoStorage<Anchor>) -> Bool {
        lhs.userInfo == rhs.userInfo
    }
}


extension UserInfoStorage: CustomStringConvertible {
    var description: String {
        "UserInfoStorage(\(userInfo.keys.joined(separator: ", ")))"
    }
}
