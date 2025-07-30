//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport)
import SpeziScheduler
import SpeziViews
import SwiftUI


/// A tile view that present instructions for an event.
///
/// This view presents an occurrence of an event and renders the instructions of the task.
/// Creating a simple instructions tile is as easy as passing the event instance.
///
/// You can supply an optional action closure that automatically places a ``EventActionButton`` that allows you to mark the event as completed or
/// present other UI components that can be used to complete the event (e.g., a questionnaire view inside a sheet).
///
/// ```swift
/// InstructionsTile(event) {
///     event.complete()
/// }
/// ```
///
/// - Tip: Use the ``SwiftUICore/View/taskCategoryAppearance(for:label:image:)`` modifier to define the ``SpeziScheduler/Task/Category/Appearance`` of a category.
///
/// ### Providing hints and tips
///
/// Sometimes it might be necessary to provide more detailed information or explanation about a event. You can supply a "More Information" view to the tile.
/// In this case a small "(i)" button will be displayed that presents the view as a sheet.
///
/// The example below renders a event for a task to collect weight measurements. A custom `MeasurementsExplanationView` provides easy-to-follow steps on how
/// to use a Bluetooth-connected weight scale to record a new weight measurement.
///
/// ```swift
/// InstructionsTile(event, more: {
///     MeasurementsExplanationView()
/// })
/// ```
public struct InstructionsTile<Header: View, Info: View, Footer: View>: View {
    /// The visibility of a component of an ``InstructionsTile``.
    public enum ComponentVisibility: Hashable, Sendable {
        /// The component should always be visible.
        case showAlways
        /// The component should be hidden if the event has already been completed.
        case hideIfCompleted
    }
    
    private let alignment: HorizontalAlignment
    private let event: Event
    private let header: Header
    private let footer: Footer
    private let footerVisibility: ComponentVisibility
    private let moreInfo: Info
    private let moreInfoVisibility: ComponentVisibility
    
    @State private var isShowingMoreInfoSheet: Bool = false
    
    
    private var moreButton: some View {
        Button {
            isShowingMoreInfoSheet = true
        } label: {
            Label {
                Text("More Information", bundle: .module)
            } icon: {
                Image(systemName: "info.circle")
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("More Information")
    }
    
    private var moreButtonCompact: some View {
        moreButton
            .labelStyle(.iconOnly)
            .font(.title3)
    }
    
    private var moreButtonExtended: some View {
        moreButton
            .labelStyle(.titleAndIcon)
            .font(.footnote)
    }
    
    private var tileAlignment: HorizontalAlignment {
        if event.isCompleted {
            .leading
        } else {
            alignment
        }
    }
    
    public var body: some View {
        SimpleTile(alignment: tileAlignment) {
            if event.isCompleted {
                HStack {
                    CompletedTileHeader(alignment: tileAlignment) {
                        Text(event.task.title)
                    }
                    switch moreInfoVisibility {
                    case .showAlways:
                        Spacer()
                        moreButtonCompact
                    case .hideIfCompleted:
                        EmptyView() // if we end up in here, the event is already completed.
                    }
                }
            } else if Info.self != EmptyView.self {
                let layout = alignment == .center
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .center))
                layout {
                    header
                    if alignment == .center {
                        moreButtonExtended
                    } else {
                        if alignment == .leading {
                            Spacer()
                        }
                        moreButtonCompact
                    }
                }
            } else {
                header
            }
        } body: {
            Text(event.task.instructions)
                .font(.callout)
        } footer: {
            switch footerVisibility {
            case .showAlways:
                footer
            case .hideIfCompleted:
                if !event.isCompleted {
                    footer
                }
            }
        }
        .sheet(isPresented: $isShowingMoreInfoSheet) {
            moreInfo
        }
        .accessibilityAction(named: Text("More Information")) {
            isShowingMoreInfoSheet = true
        }
    }
    
    
    /// Create a new instructions with a header, a details view and a footer view.
    /// - Parameters:
    ///   - event: The event instance.
    ///   - alignment: The horizontal alignment of the tile.
    ///   - header: A custom header that is shown on the top of the tile. You can use the [`TileHeader`](https://swiftpackageindex.com/stanfordspezi/speziviews/documentation/speziviews/tileheader)
    ///   - more: An optional view that is presented as a sheet if the user presses the "more information" button. The view can be used to provide additional explanation or instructions for a task.
    ///   - footer: A footer that is shown below the body of the tile. You may use the ``EventActionButton``.
    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading,
        footerVisibility: ComponentVisibility = .hideIfCompleted,
        moreInfoVisibility: ComponentVisibility = .hideIfCompleted,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer,
        @ViewBuilder more: () -> Info
    ) {
        self.alignment = alignment
        self.event = event
        self.header = header()
        self.footer = footer()
        self.moreInfo = more()
        self.footerVisibility = footerVisibility
        self.moreInfoVisibility = moreInfoVisibility
    }
}


extension InstructionsTile {
    /// Create a new instructions with an action button.
    ///
    /// This initializers uses the ``EventActionButton``.
    /// - Parameters:
    ///   - event: The event instance.
    ///   - alignment: The horizontal alignment of the tile.
    ///   - action: The closure that is executed if the action button is pressed.
    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading,
        footerVisibility: ComponentVisibility = .hideIfCompleted,
        action: @escaping () -> Void
    ) where Header == DefaultTileHeader, Footer == EventActionButton, Info == EmptyView {
        self.init(event, alignment: alignment, footerVisibility: footerVisibility, action: action) {
            DefaultTileHeader(event, alignment: alignment)
        }
    }
    
    /// Create a new instructions with a header and an action button.
    ///
    /// This initializers uses the ``EventActionButton``.
    /// - Parameters:
    ///   - event: The event instance.
    ///   - alignment: The horizontal alignment of the tile.
    ///   - action: The closure that is executed if the action button is pressed.
    ///   - header: A custom header that is shown on the top of the tile. You can use the [`TileHeader`](https://swiftpackageindex.com/stanfordspezi/speziviews/documentation/speziviews/tileheader)
    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading,
        footerVisibility: ComponentVisibility = .hideIfCompleted,
        action: @escaping () -> Void,
        @ViewBuilder header: () -> Header
    ) where Footer == EventActionButton, Info == EmptyView {
        self.init(event, alignment: alignment, footerVisibility: footerVisibility, action: action, header: header) {
            EmptyView()
        }
    }

    /// Create a new instructions with an action button and a details view.
    ///
    /// This initializers uses the ``EventActionButton``.
    /// - Parameters:
    ///   - event: The event instance.
    ///   - alignment: The horizontal alignment of the tile.
    ///   - action: The closure that is executed if the action button is pressed.
    ///   - more: An optional view that is presented as a sheet if the user presses the "more information" button. The view can be used to provide additional explanation or instructions for a task.
    @_disfavoredOverload
    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading,
        footerVisibility: ComponentVisibility = .hideIfCompleted,
        moreInfoVisibility: ComponentVisibility = .hideIfCompleted,
        action: @escaping () -> Void,
        @ViewBuilder more: () -> Info
    ) where Header == DefaultTileHeader, Footer == EventActionButton {
        self.init(
            event,
            alignment: alignment,
            footerVisibility: footerVisibility,
            moreInfoVisibility: moreInfoVisibility,
            action: action,
            header: { DefaultTileHeader(event, alignment: alignment) },
            more: more
        )
    }
    
    /// Create a new instructions with a header, an action button and a details view.
    ///
    /// This initializers uses the ``EventActionButton``.
    /// - Parameters:
    ///   - event: The event instance.
    ///   - alignment: The horizontal alignment of the tile.
    ///   - action: The closure that is executed if the action button is pressed.
    ///   - header: A custom header that is shown on the top of the tile. You can use the [`TileHeader`](https://swiftpackageindex.com/stanfordspezi/speziviews/documentation/speziviews/tileheader)
    ///   - more: An optional view that is presented as a sheet if the user presses the "more information" button. The view can be used to provide additional explanation or instructions for a task.
    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading,
        footerVisibility: ComponentVisibility = .hideIfCompleted,
        moreInfoVisibility: ComponentVisibility = .hideIfCompleted,
        action: @escaping () -> Void,
        @ViewBuilder header: () -> Header,
        @ViewBuilder more: () -> Info
    ) where Footer == EventActionButton {
        self.init(
            event,
            alignment: alignment,
            footerVisibility: footerVisibility,
            moreInfoVisibility: moreInfoVisibility,
            header: header,
            footer: { EventActionButton(event: event, action: action) },
            more: more
        )
    }
    
    /// Create a new instructions.
    ///
    /// This initializers uses the ``DefaultTileHeader``.
    /// - Parameters:
    ///   - event: The event instance.
    ///   - alignment: The horizontal alignment of the tile.
    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading
    ) where Header == DefaultTileHeader, Footer == EmptyView, Info == EmptyView {
        self.init(event, alignment: alignment) {
            EmptyView()
        }
    }
    
    /// Create a new instructions with a footer view.
    ///
    /// This initializers uses the ``DefaultTileHeader``.
    /// - Parameters:
    ///   - event: The event instance.
    ///   - alignment: The horizontal alignment of the tile.
    ///   - footer: A footer that is shown below the body of the tile. You may use the ``EventActionButton``.
    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading,
        footerVisibility: ComponentVisibility = .hideIfCompleted,
        @ViewBuilder footer: () -> Footer
    ) where Header == DefaultTileHeader, Info == EmptyView {
        self.init(
            event,
            alignment: alignment,
            footerVisibility: footerVisibility,
            header: { DefaultTileHeader(event, alignment: alignment) },
            footer: footer
        )
    }

    /// Create a new instructions tile with a details view.
    ///
    /// This initializers uses the ``DefaultTileHeader``.
    /// - Parameters:
    ///   - event: The event instance.
    ///   - alignment: The horizontal alignment of the tile.
    ///   - more: An optional view that is presented as a sheet if the user presses the "more information" button. The view can be used to provide additional explanation or instructions for a task.
    @_disfavoredOverload
    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading,
        moreInfoVisibility: ComponentVisibility = .hideIfCompleted,
        @ViewBuilder more: () -> Info
    ) where Header == DefaultTileHeader, Footer == EmptyView {
        self.init(
            event,
            alignment: alignment,
            moreInfoVisibility: moreInfoVisibility,
            header: { DefaultTileHeader(event, alignment: alignment) },
            more: more
        )
    }
    
    /// Create a new instructions with a header and no action view.
    /// - Parameters:
    ///   - event: The event instance.
    ///   - alignment: The horizontal alignment of the tile.
    ///   - header: A custom header that is shown on the top of the tile. You can use the [`TileHeader`](https://swiftpackageindex.com/stanfordspezi/speziviews/documentation/speziviews/tileheader)
    @_disfavoredOverload
    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading,
        @ViewBuilder header: () -> Header
    ) where Footer == EmptyView, Info == EmptyView {
        self.init(event, alignment: alignment, header: header) {
            EmptyView()
        }
    }
    
    /// Create a new instructions with a header and a footer view.
    /// - Parameters:
    ///   - event: The event instance.
    ///   - alignment: The horizontal alignment of the tile.
    ///   - header: A custom header that is shown on the top of the tile. You can use the [`TileHeader`](https://swiftpackageindex.com/stanfordspezi/speziviews/documentation/speziviews/tileheader)
    ///   - footer: A footer that is shown below the body of the tile. You may use the ``EventActionButton``.
    @_disfavoredOverload
    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading,
        footerVisibility: ComponentVisibility = .hideIfCompleted,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer
    ) where Info == EmptyView {
        self.init(event, alignment: alignment, footerVisibility: footerVisibility, header: header, footer: footer) {
            EmptyView()
        }
    }

    /// Create a new instructions tile with a custom header and a details view.
    /// - Parameters:
    ///   - event: The event instance.
    ///   - alignment: The horizontal alignment of the tile.
    ///   - header: A custom header that is shown on the top of the tile. You can use the [`TileHeader`](https://swiftpackageindex.com/stanfordspezi/speziviews/documentation/speziviews/tileheader)
    ///     view as a basis for your implementation.
    ///   - more: An optional view that is presented as a sheet if the user presses the "more information" button. The view can be used to provide additional explanation or instructions for a task.
    public init(
        _ event: Event,
        alignment: HorizontalAlignment = .leading,
        moreInfoVisibility: ComponentVisibility = .hideIfCompleted,
        @ViewBuilder header: () -> Header,
        @ViewBuilder more: () -> Info
    ) where Footer == EmptyView {
        self.init(
            event,
            alignment: alignment,
            moreInfoVisibility: moreInfoVisibility,
            header: header,
            footer: { EmptyView() },
            more: more
        )
    }
}


#if DEBUG
#Preview(traits: .schedulerSampleData) {
    @EventQuery(in: .sampleEventRange)
    @Previewable var events

    if let error = $events.fetchError {
        Text("Error Occurrence: \(error)")
    } else if let first = events.first {
        List {
            InstructionsTile(first) {
                _ = try? first.complete()
            }
        }
    } else {
        ProgressView()
    }
}


#Preview(traits: .schedulerSampleData) {
    @EventQuery(in: .sampleEventRange)
    @Previewable var events

    if let error = $events.fetchError {
        Text("Error Occurrence: \(error)")
    } else if let first = events.first {
        List {
            InstructionsTile(first, alignment: .center) {
                _ = try? first.complete()
            } more: {
                Text("More information about the task!")
            }
        }
    } else {
        ProgressView()
    }
}
#endif
