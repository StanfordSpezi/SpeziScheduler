//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziViews
import SwiftUI


struct NotificationTriggerLabel: View {
    private let nextTriggerDate: Date

    @ManagedViewUpdate private var viewUpdate

    var body: some View {
        Group {
            if nextTriggerDate > .now {
                Text("in \(Text(.currentDate, format: SystemFormatStyle.DateOffset(to: nextTriggerDate, sign: .never)))", bundle: .module)
            } else {
                Text("\(Text(.currentDate, format: SystemFormatStyle.DateOffset(to: nextTriggerDate, sign: .never))) ago", bundle: .module)
            }
        }
            .onAppear {
                viewUpdate.schedule(at: nextTriggerDate)
            }
    }

    init(_ nextTriggerDate: Date) {
        self.nextTriggerDate = nextTriggerDate
    }
}
