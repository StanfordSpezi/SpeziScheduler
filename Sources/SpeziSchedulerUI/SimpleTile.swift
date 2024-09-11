//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


struct TileAction<Label: View> {
    let action: () -> Void
    let label: Label
    let disabled: Bool

    init(action: @escaping () -> Void, label: Label, disabled: Bool = false) {
        self.action = action
        self.label = label
        self.disabled = disabled
    }

    init(disabled: Bool = false, action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.disabled = disabled
        self.action = action
        self.label = label()
    }
}


struct SimpleTile<Header: View, Footer: View, ActionLabel: View>: View {
    private let alignment: HorizontalAlignment
    private let header: Header
    private let footer: Footer
    private let action: TileAction<ActionLabel>?

    var body: some View {
        VStack(alignment: alignment) {
            tileLabel

            if let action {
                Button(action: action.action) {
                    action.label
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                    .disabled(action.disabled)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
        }
            .containerShape(Rectangle())
#if !TEST && !targetEnvironment(simulator) // it's easier to UI test for us without the accessibility representation
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

        if Footer.self != EmptyView.self || ActionLabel.self != EmptyView.self {
            Divider()
                .padding(.bottom, 4)
        }

        footer
    }

    init( // swiftlint:disable:this function_default_parameter_at_end
        alignment: HorizontalAlignment = .leading,
        action: TileAction<ActionLabel>?,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer
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
        self.init(alignment: alignment, action: TileAction(action: action, label: actionLabel), header: header, footer: footer)
    }

    init(
        alignment: HorizontalAlignment = .leading,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) where ActionLabel == EmptyView {
        self.init(alignment: alignment, action: nil, header: header, footer: footer)
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
