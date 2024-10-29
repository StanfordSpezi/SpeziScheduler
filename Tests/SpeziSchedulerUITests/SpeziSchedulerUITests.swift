//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SnapshotTesting
import SpeziScheduler
@_spi(TestingSupport)
import SpeziSchedulerUI
import SwiftUI
import XCTest


final class SpeziSchedulerUITests: XCTestCase {
    @MainActor
    func testTileHeaderLayout() {
        let event = SchedulerSampleData.makeTestEvent()

        let leadingTileHeader = DefaultTileHeader(event, alignment: .leading)
        let centerTileHeader = DefaultTileHeader(event, alignment: .center)
        let trailingTileHeader = DefaultTileHeader(event, alignment: .trailing)

#if os(iOS)
        assertSnapshot(of: leadingTileHeader, as: .image(layout: .device(config: .iPhone13Pro)), named: "leading")
        assertSnapshot(of: centerTileHeader, as: .image(layout: .device(config: .iPhone13Pro)), named: "center")
        assertSnapshot(of: trailingTileHeader, as: .image(layout: .device(config: .iPhone13Pro)), named: "trailing")
#endif
    }

    @MainActor
    func testTileHeaderLayoutWithCategoryAppearance() {
        let event = SchedulerSampleData.makeTestEvent()
        
        let leadingTileHeader = DefaultTileHeader(event, alignment: .leading)
            .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))
        let centerTileHeader = DefaultTileHeader(event, alignment: .center)
            .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))
        let trailingTileHeader = DefaultTileHeader(event, alignment: .trailing)
            .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))

#if os(iOS)
        assertSnapshot(of: leadingTileHeader, as: .image(layout: .device(config: .iPhone13Pro)), named: "leading")
        assertSnapshot(of: centerTileHeader, as: .image(layout: .device(config: .iPhone13Pro)), named: "center")
        assertSnapshot(of: trailingTileHeader, as: .image(layout: .device(config: .iPhone13Pro)), named: "trailing")
#endif
    }

    @MainActor
    func testInstructionsTile() {
        let event = SchedulerSampleData.makeTestEvent()

        let tileLeading = InstructionsTile(event, alignment: .leading)
        let tileCenter = InstructionsTile(event, alignment: .center)
        let tileTrailing = InstructionsTile(event, alignment: .trailing)

        let tileLeadingMore = InstructionsTile(event, alignment: .leading, more: {
            Text("More Information")
        })
        let tileCenterMore = InstructionsTile(event, alignment: .center, more: {
            Text("More Information")
        })
        let tileTrailingMore = InstructionsTile(event, alignment: .trailing, more: {
            Text("More Information")
        })

        let tileWithAction = InstructionsTile(event) {
            print("Action was pressed")
        }

#if os(iOS)
        assertSnapshot(of: tileLeading, as: .image(layout: .device(config: .iPhone13Pro)), named: "leading")
        assertSnapshot(of: tileCenter, as: .image(layout: .device(config: .iPhone13Pro)), named: "center")
        assertSnapshot(of: tileTrailing, as: .image(layout: .device(config: .iPhone13Pro)), named: "trailing")

        assertSnapshot(of: tileLeadingMore, as: .image(layout: .device(config: .iPhone13Pro)), named: "leading-more")
        assertSnapshot(of: tileCenterMore, as: .image(layout: .device(config: .iPhone13Pro)), named: "center-more")
        assertSnapshot(of: tileTrailingMore, as: .image(layout: .device(config: .iPhone13Pro)), named: "trailing-more")

        assertSnapshot(of: tileWithAction, as: .image(layout: .device(config: .iPhone13Pro)), named: "action")
#endif
    }

    @MainActor
    func testInstructionsTileWithCategoryAppearance() {
        let event = SchedulerSampleData.makeTestEvent()

        let tileLeading = InstructionsTile(event, alignment: .leading)
            .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))
        let tileCenter = InstructionsTile(event, alignment: .center)
            .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))
        let tileTrailing = InstructionsTile(event, alignment: .trailing)
            .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))

        let tileLeadingMore = InstructionsTile(event, alignment: .leading, more: {
            Text("More Information")
        })
            .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))
        let tileCenterMore = InstructionsTile(event, alignment: .center, more: {
            Text("More Information")
        })
            .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))
        let tileTrailingMore = InstructionsTile(event, alignment: .trailing, more: {
            Text("More Information")
        })
            .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))

#if os(iOS)
        assertSnapshot(of: tileLeading, as: .image(layout: .device(config: .iPhone13Pro)), named: "leading")
        assertSnapshot(of: tileCenter, as: .image(layout: .device(config: .iPhone13Pro)), named: "center")
        assertSnapshot(of: tileTrailing, as: .image(layout: .device(config: .iPhone13Pro)), named: "trailing")

        assertSnapshot(of: tileLeadingMore, as: .image(layout: .device(config: .iPhone13Pro)), named: "leading-more")
        assertSnapshot(of: tileCenterMore, as: .image(layout: .device(config: .iPhone13Pro)), named: "center-more")
        assertSnapshot(of: tileTrailingMore, as: .image(layout: .device(config: .iPhone13Pro)), named: "trailing-more")
#endif
    }
}
