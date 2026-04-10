//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

#if os(iOS)

import SnapshotTesting
import SpeziScheduler
@_spi(TestingSupport)
@testable import SpeziSchedulerUI
import SwiftUI
import XCTest


final class SpeziSchedulerUITests: XCTestCase {
    private func withFixedLocale(@ViewBuilder _ view: () -> some View) -> some View {
        view().environment(\.locale, Locale(identifier: "en_US"))
    }
    
    @MainActor
    func testTileHeaderLayout() {
        let event = SchedulerSampleData.makeTestEvent()
        let leadingTileHeader = withFixedLocale {
            DefaultTileHeader(event, alignment: .leading)
                .disableCategoryDefaultAppearances()
        }
        let centerTileHeader = withFixedLocale {
            DefaultTileHeader(event, alignment: .center)
                .disableCategoryDefaultAppearances()
        }
        let trailingTileHeader = withFixedLocale {
            DefaultTileHeader(event, alignment: .trailing)
                .disableCategoryDefaultAppearances()
        }
        assertSnapshot(of: leadingTileHeader, as: .image(layout: .device(config: .iPhone13Pro)), named: "leading")
        assertSnapshot(of: centerTileHeader, as: .image(layout: .device(config: .iPhone13Pro)), named: "center")
        assertSnapshot(of: trailingTileHeader, as: .image(layout: .device(config: .iPhone13Pro)), named: "trailing")

    }

    @MainActor
    func testTileHeaderLayoutWithCategoryAppearance() {
        let event = SchedulerSampleData.makeTestEvent()
        
        let leadingTileHeader = withFixedLocale{
            DefaultTileHeader(event, alignment: .leading)
                .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))
        }
        let centerTileHeader = withFixedLocale{
            DefaultTileHeader(event, alignment: .center)
                .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))
        }
        let trailingTileHeader = withFixedLocale{
            DefaultTileHeader(event, alignment: .trailing)
                .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))
        }
        
        assertSnapshot(of: leadingTileHeader, as: .image(layout: .device(config: .iPhone13Pro)), named: "leading")
        assertSnapshot(of: centerTileHeader, as: .image(layout: .device(config: .iPhone13Pro)), named: "center")
        assertSnapshot(of: trailingTileHeader, as: .image(layout: .device(config: .iPhone13Pro)), named: "trailing")
    }

    @MainActor
    func testInstructionsTile() {
        let event = SchedulerSampleData.makeTestEvent()

        let tileLeading = withFixedLocale {
            InstructionsTile(event, alignment: .leading)
                .disableCategoryDefaultAppearances()
        }
        let tileCenter = withFixedLocale {
            InstructionsTile(event, alignment: .center)
                .disableCategoryDefaultAppearances()
        }
        let tileTrailing = withFixedLocale {
            InstructionsTile(event, alignment: .trailing)
                .disableCategoryDefaultAppearances()
        }

        let tileLeadingMore = withFixedLocale {
            InstructionsTile(event, alignment: .leading, more: {
                Text("More Information")
            })
            .disableCategoryDefaultAppearances()
        }
        let tileCenterMore = withFixedLocale {
            InstructionsTile(event, alignment: .center, more: {
                Text("More Information")
            })
            .disableCategoryDefaultAppearances()
        }
        let tileTrailingMore = withFixedLocale {
            InstructionsTile(event, alignment: .trailing, more: {
                Text("More Information")
            })
            .disableCategoryDefaultAppearances()
        }

        let tileWithAction = withFixedLocale {
            InstructionsTile(event) {
                print("Action was pressed")
            }
            .disableCategoryDefaultAppearances()
        }
        
        assertSnapshot(of: tileLeading, as: .image(layout: .device(config: .iPhone13Pro)), named: "leading")
        assertSnapshot(of: tileCenter, as: .image(layout: .device(config: .iPhone13Pro)), named: "center")
        assertSnapshot(of: tileTrailing, as: .image(layout: .device(config: .iPhone13Pro)), named: "trailing")

        assertSnapshot(of: tileLeadingMore, as: .image(layout: .device(config: .iPhone13Pro)), named: "leading-more")
        assertSnapshot(of: tileCenterMore, as: .image(layout: .device(config: .iPhone13Pro)), named: "center-more")
        assertSnapshot(of: tileTrailingMore, as: .image(layout: .device(config: .iPhone13Pro)), named: "trailing-more")

        // Note to whoever is reading this at some point in the future:
        // if this test fails, and the reference image is fully transparent and the actual image is not,
        // simply delete the reference image and replace it with a new one.
        // See also: https://github.com/pointfreeco/swift-snapshot-testing/issues/1029
        assertSnapshot(of: tileWithAction, as: .image(layout: .device(config: .iPhone13Pro)), named: "action")
    }

    @MainActor
    func testInstructionsTileWithCategoryAppearance() {
        let event = SchedulerSampleData.makeTestEvent()

        let tileLeading = withFixedLocale {
            InstructionsTile(event, alignment: .leading)
                .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))
        }
        let tileCenter = withFixedLocale {
            InstructionsTile(event, alignment: .center)
                .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))
        }
        let tileTrailing = withFixedLocale {
            InstructionsTile(event, alignment: .trailing)
                .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))
        }

        let tileLeadingMore = withFixedLocale {
            InstructionsTile(event, alignment: .leading, more: {
                Text("More Information")
            })
            .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))
        }
        let tileCenterMore = withFixedLocale {
            InstructionsTile(event, alignment: .center, more: {
                Text("More Information")
            })
            .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))
        }
        let tileTrailingMore = withFixedLocale {
            InstructionsTile(event, alignment: .trailing, more: {
                Text("More Information")
            })
            .taskCategoryAppearance(for: .questionnaire, label: "Questionnaire", image: .system("list.clipboard.fill"))
        }
        assertSnapshot(of: tileLeading, as: .image(layout: .device(config: .iPhone13Pro)), named: "leading")
        assertSnapshot(of: tileCenter, as: .image(layout: .device(config: .iPhone13Pro)), named: "center")
        assertSnapshot(of: tileTrailing, as: .image(layout: .device(config: .iPhone13Pro)), named: "trailing")

        assertSnapshot(of: tileLeadingMore, as: .image(layout: .device(config: .iPhone13Pro)), named: "leading-more")
        assertSnapshot(of: tileCenterMore, as: .image(layout: .device(config: .iPhone13Pro)), named: "center-more")
        assertSnapshot(of: tileTrailingMore, as: .image(layout: .device(config: .iPhone13Pro)), named: "trailing-more")
    }
}

#endif
