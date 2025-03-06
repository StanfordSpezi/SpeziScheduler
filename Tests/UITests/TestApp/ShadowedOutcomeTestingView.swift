//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
import SpeziScheduler
import SwiftUI
import XCTestApp


struct ShadowedOutcomeTestingView: View { // swiftlint:disable:this file_types_order
    @Environment(\.calendar)
    private var cal
    @Environment(Scheduler.self)
    private var scheduler
    
    var body: some View {
        TestAppView(testCase: TestCase(cal: cal, scheduler: scheduler))
    }
}


private struct TestCase: TestAppTestCase {
    let cal: Calendar
    let scheduler: Scheduler
    
    func runTests() throws {
        let registerTask = {
            try self.scheduler.createOrUpdateTask(
                id: "shadowed-outcomes-testing-task",
                title: "Shadowed Outcomes Testing Task",
                instructions: "",
                schedule: .daily(hour: 23, minute: 59, startingAt: .today)
            ).task
        }
        let task = try registerTask()
        let events = try scheduler.queryEvents(for: task, in: cal.rangeOfWeek(for: cal.startOfNextWeek(for: .now)))
        for event in events.dropFirst(2) {
            try event.complete(ignoreCompletionPolicy: true)
        }
        try XCTAssertNoThrow(try registerTask())
    }
}
