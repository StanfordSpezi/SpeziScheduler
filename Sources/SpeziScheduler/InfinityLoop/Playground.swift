//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


struct PlaygroundList: View {
    @EventQuery(in: .today..<Date.tomorrow)
    private var events

    var body: some View {
        List(events) { event in
            InstructionsTile(event)
        }
    }
}


#if DEBUG
#Preview {
    PlaygroundList()
        .previewWith {
            ILScheduler()
        }
}
#endif
