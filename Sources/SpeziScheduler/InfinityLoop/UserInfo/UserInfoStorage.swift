//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation


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

    init() {
        self.userInfo = [:]
    }

    func contains<Source: UserInfoKey<Anchor>>(_ source: Source.Type) -> Bool {
        userInfo[source.identifier] != nil
    }
}


extension UserInfoStorage {
    func get<Source: UserInfoKey<Anchor>>(_ source: Source.Type, cache: inout RepositoryCache) -> Source.Value? {
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
            print("Unable to decode \(data) for type \(source): \(error)")
            // TODO: log error!
            return nil
        }
    }

    mutating func set<Source: UserInfoKey<Anchor>>(_ source: Source.Type, value newValue: Source.Value?, cache: inout RepositoryCache) {
        cache.repository.set(source, value: newValue)

        if let newValue {
            do {
                // TODO: property list encoder is a bit finicky!
                userInfo[source.identifier] = try PropertyListEncoder().encode(SingleValueWrapper(value: newValue))
            } catch {
                print("Failed to encode userInfo value \(newValue) for key \(Source.self): \(error)")
                // TODO: log error!
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

    init(rawValue: [String : Data]) {
        self.userInfo = rawValue
    }
}

extension UserInfoStorage: Codable {/*
    private struct CodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        
        init?(intValue: Int) {
            nil
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        var userInfo: [String: Data] = [:]
        for key in container.allKeys {
            let data = try container.decode(Data.self, forKey: key)
            userInfo[key.stringValue] = data
        }
        self.userInfo = userInfo
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        for (key, data) in userInfo {
            try container.encode(data, forKey: CodingKeys(stringValue: key))
        }
    }*/
}


extension UserInfoStorage: Equatable {
    static func == (lhs: UserInfoStorage<Anchor>, rhs: UserInfoStorage<Anchor>) -> Bool {
        lhs.userInfo == rhs.userInfo
    }
}
