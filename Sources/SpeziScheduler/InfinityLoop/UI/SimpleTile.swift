//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


struct SimpleTile<Header: View, Footer: View, ActionLabel: View>: View {
    private struct Action {
        let action: () -> Void
        let label: ActionLabel
    }

    private let alignment: HorizontalAlignment
    private let header: Header
    private let footer: Footer
    private let action: Action?

    var body: some View {
        VStack(alignment: alignment) {
            tileLabel

            if let action {
                Button(action: action.action) {
                    action.label
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
        }
            .containerShape(Rectangle())
        #if !TEST // it's easier to UI test for us without the accessibility representation
            .accessibilityRepresentation {
                if let action {
                    Button(action: action.action) {
                        tileLabel
                    }
                } else {
                    tileLabel
                        .accessibilityElement(children: .combine)
                }
            }
        #endif
    }


    @ViewBuilder var tileLabel: some View {
        header

        if Footer.self != EmptyView.self || Action.self != EmptyView.self {
            Divider()
                .padding(.bottom, 4)
        }

        footer
    }

    private init(
        alignment: HorizontalAlignment,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer,
        action: Action?
    ) {
        self.alignment = alignment
        self.header = header()
        self.footer = footer()
        self.action = action
    }


    init(
        alignment: HorizontalAlignment = .leading,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer = { EmptyView() },
        action: @escaping () -> Void,
        @ViewBuilder actionLabel: () -> ActionLabel
    ) {
        self.init(alignment: alignment, header: header, footer: footer, action: Action(action: action, label: actionLabel()))
    }

    init(
        alignment: HorizontalAlignment = .leading,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) where ActionLabel == EmptyView {
        self.init(alignment: alignment, header: header, footer: footer, action: nil)
    }
}


#if DEBUG
#Preview {
    List {
        SimpleTile {
            Text(verbatim: "Test Tile Header")
        } footer: {
            Text(verbatim: "The description of a tile")
        }
    }
}

#Preview {
    List {
        SimpleTile {
            Text(verbatim: "Test Tile Header only")
        }
    }
}
#endif
