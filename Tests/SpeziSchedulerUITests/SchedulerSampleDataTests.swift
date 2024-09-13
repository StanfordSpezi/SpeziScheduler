//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@testable import SpeziSchedulerUI
import XCTest

final class SchedulerSampleDataTests: XCTestCase {
    @MainActor
    func testSchedulerSampleData() throws {
        let container = try SchedulerSampleData.makeSharedContext()

        let scheduler = Scheduler(testingContainer: container)
        withDependencyResolution {
            scheduler
        }

        let results = try scheduler.queryTasks(for: Date.yesterday..<Date.tomorrow)
        XCTAssertEqual(results.count, 1, "Received unexpected amount of tasks in query.")

        let events = try scheduler.queryEvents(for: Date.yesterday..<Date.tomorrow)
        XCTAssertEqual(events.count, 1, "Received unexpected amount of events in query.")
    }
}
