//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


struct CompletedTile<Title: View, Description: View>: View {
    private let title: Title
    private let description: Description

    var body: some View {
        if Description.self == EmptyView.self {
            SimpleTile {
                header
            }
        } else {
            SimpleTile {
                header
            } footer: {
                description
                    .font(.callout)
            }
        }
    }

    @ViewBuilder private var header: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.custom("Completed Icon", size: 30, relativeTo: .title))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                title
                    .font(.headline)

                Text("Completed", comment: "Completed Tile. Subtitle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    init(@ViewBuilder title: () -> Title, @ViewBuilder description: () -> Description = { EmptyView() }) {
        self.title = title()
        self.description = description()
    }
}


#if DEBUG
#Preview {
    List {
        CompletedTile {
            Text(verbatim: "Test Task")
        } description: {
            Text(verbatim: "A nice description of a test task.")
        }
    }
}

#Preview {
    List {
        CompletedTile {
            Text(verbatim: "Test Task")
        }
    }
}
#endif
