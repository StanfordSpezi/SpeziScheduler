//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Spezi
@_spi(APISupport)
import SpeziScheduler
import SpeziSchedulerUI
import SwiftUI


struct ObserveNewOutcomesTestingView: View {
    @Environment(Scheduler.self)
    private var scheduler
    
    @EventQuery(in: Calendar.current.rangeOfDay(for: .now))
    private var events
    
    @State private var observationToken: AnyObject?
    @State private var didTrigger = false
    
    var body: some View {
        Form {
            Section {
                LabeledContent("did trigger", value: didTrigger.description)
            }
            Section {
                if let event = events.first(where: { $0.task.id == "TESTTESTTEST" }) {
                    InstructionsTile(event) {
                        _ = try? event.complete()
                    } more: {
                        EventDetailView(event)
                    }
                }
            }
        }
        .onAppear {
            guard observationToken == nil else {
                return
            }
            observationToken = scheduler.observeNewOutcomes { outcome in
                if outcome.task.id == "TESTTESTTEST" {
                    didTrigger = true
                }
            }
        }
    }
}
