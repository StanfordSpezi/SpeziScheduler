//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziViews
import SwiftUI


struct CompletedTileHeader<Title: View>: View {
    private let title: Title

    var body: some View {
        TileHeader {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.custom("Completed Icon", size: 30, relativeTo: .title))
                .accessibilityHidden(true)
        } title: {
            title
        } subheadline: {
            Text("Completed", bundle: .module, comment: "Completed Tile. Subtitle")
        }
    }

    init(@ViewBuilder title: () -> Title) {
        self.title = title()
    }
}


#if DEBUG
#Preview {
    List {
        CompletedTileHeader {
            Text(verbatim: "Test Task")
        }
    }
}
#endif
