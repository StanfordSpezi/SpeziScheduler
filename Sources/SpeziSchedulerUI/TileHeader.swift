//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziViews
import SwiftUI


public struct TileHeader<Icon: View, Title: View, Subheadline: View>: View {
    private let alignment: HorizontalAlignment
    private let icon: Icon
    private let title: Title
    private let subheadline: Subheadline

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    public var body: some View {
        if alignment == .center {
            VStack(alignment: .center, spacing: 4) {
                icon
                modifiedTitle
                modifiedSubheadline
            }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack {
                    icon

                    VStack(alignment: alignment, spacing: 4) {
                        modifiedTitle
                        modifiedSubheadline
                    }
                }

                VStack(alignment: alignment, spacing: 4) {
                    HStack(alignment: .center) {
                        if dynamicTypeSize < .accessibility3 {
                            icon
                        }
                        modifiedTitle
                    }
                    modifiedSubheadline
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var modifiedTitle: some View {
        title
            .font(.headline)
    }

    private var modifiedSubheadline: some View {
        subheadline
            .font(.subheadline)
            .foregroundColor(.secondary)
    }

    public init(
        alignment: HorizontalAlignment = .leading,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder title: () -> Title,
        @ViewBuilder subheadline: () -> Subheadline
    ) {
        self.alignment = alignment
        self.icon = icon()
        self.title = title()
        self.subheadline = subheadline()
    }
}


#if DEBUG
#Preview {
    List {
        TileHeader {
            Image(systemName: "book.pages.fill")
                .foregroundStyle(.teal)
                .font(.custom("Task Icon", size: 30, relativeTo: .headline))
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        } title: {
            Text("Awesome Book")
        } subheadline: {
            Text("This a nice book recommendation")
        }
    }
}

#Preview {
    List {
        TileHeader(alignment: .center) {
            Image(systemName: "book.pages.fill")
                .foregroundStyle(.teal)
                .font(.custom("Task Icon", size: 30, relativeTo: .headline))
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        } title: {
            Text("Awesome Book")
        } subheadline: {
            Text("This a nice book recommendation")
        }
    }
}

#Preview {
    List {
        TileHeader(alignment: .trailing) {
            Image(systemName: "book.pages.fill")
                .foregroundStyle(.teal)
                .font(.custom("Task Icon", size: 30, relativeTo: .headline))
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        } title: {
            Text("Awesome Book")
        } subheadline: {
            Text("This a nice book recommendation")
        }
    }
}
#endif
