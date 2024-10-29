//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import OSLog


private let logger = Logger(subsystem: "edu.stanford.spezi.scheduler", category: "EventQuery")


func measure<T, C: Clock>(
    clock: C = ContinuousClock(),
    name: @autoclosure @escaping () -> StaticString,
    _ action: () throws -> T
) rethrows -> T where C.Instant.Duration == Duration {
    #if DEBUG || TEST
    let start = clock.now
    let result = try action()
    let end = clock.now
    logger.debug("Performing \(name()) took \(start.duration(to: end))")
    return result
    #else
    try action()
    #endif
}


func measure<T, C: Clock>(
    isolation: isolated (any Actor)? = #isolation,
    clock: C = ContinuousClock(),
    name: @autoclosure @escaping () -> StaticString,
    _ action: () async throws -> sending T
) async rethrows -> sending T where C.Instant.Duration == Duration {
#if DEBUG || TEST
    let start = clock.now
    let result = try await action()
    let end = clock.now
    logger.debug("Performing \(name()) took \(start.duration(to: end))")
    return result
#else
    try await action()
#endif
}
