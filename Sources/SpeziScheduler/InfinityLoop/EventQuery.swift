//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Combine
import SwiftData
import SwiftUI


@propertyWrapper
@MainActor
public struct EventQuery {
    private let range: Range<Date>

    @Environment(ILScheduler.self)
    private var scheduler

    @State private var viewUpdate: UInt64 = 0
    @State private var cancelable: AnyCancellable?

    public private(set) var wrappedValue: [ILEvent]

    // TODO: projected value?

    public init(in range: Range<Date>) {
        // TODO: more flexibility in the query Predicate (e.g., query additional properties)?
        self.range = range
        self.wrappedValue = []
    }
}


extension EventQuery: DynamicProperty {
    public mutating nonisolated func update() {
        MainActor.assumeIsolated { // TODO: this is not great, update is public!
            doUpdate()
        }
    }

    private mutating func doUpdate() {
        guard let context = try? scheduler.context else {
            return // TODO: what do do?
        }

        if cancelable != nil {
            let viewUpdate = $viewUpdate
            cancelable = NotificationCenter.default.publisher(for: ModelContext.didSave, object: context)
                .sink { _ in
                    viewUpdate.wrappedValue &+= 1 // increment that automatically wraps around
                                     // TODO: on which thread are we running, MainActor?
                }
        }

        do {
            // TODO: should this run on the main thread?
            wrappedValue = try scheduler.queryEvents(for: range)
        } catch {
            // TODO: log error!
        }
    }
}
