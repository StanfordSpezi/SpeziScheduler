//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import XCTest
import XCTestExtensions


class TestAppUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }


    @MainActor
    func testBasicEventInteraction() {
        let app = XCUIApplication()
        app.launch()

        XCTAssert(app.wait(for: .runningForeground, timeout: 2.0))

        XCTAssert(app.staticTexts["Schedule"].waitForExistence(timeout: 2.0))

        XCTAssert(app.staticTexts["Today"].exists)
        XCTAssert(app.staticTexts["Social Support Questionnaire"].exists)
        XCTAssert(app.staticTexts["Questionnaire"].exists)
        XCTAssert(app.staticTexts["4:00 PM"].exists)

        XCTAssert(app.buttons["More Information"].exists)
        app.buttons["More Information"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars.staticTexts["More Information"].waitForExistence(timeout: 4.0))
        XCTAssertTrue(app.staticTexts["Instructions"].exists)
        XCTAssertTrue(app.staticTexts["About"].exists)

        XCTAssertTrue(app.navigationBars.buttons["Close"].exists)
        app.navigationBars.buttons["Close"].tap()

        XCTAssertTrue(app.staticTexts["Schedule"].waitForExistence(timeout: 2.0))

        XCTAssert(app.buttons["Complete Questionnaire"].exists)
        app.buttons["Complete Questionnaire"].tap()

        XCTAssertTrue(app.staticTexts["Completed"].waitForExistence(timeout: 2.0))
    }

    @MainActor
    func testNotificationScheduling() {
        let app = XCUIApplication()
        app.deleteAndLaunch(withSpringboardAppName: "TestApp")

        XCTAssert(app.wait(for: .runningForeground, timeout: 2.0))

        XCTAssert(app.tabBars.buttons["Notifications"].waitForExistence(timeout: 2.0))
        app.tabBars.buttons["Notifications"].tap()

        XCTAssert(app.staticTexts["Pending Notifications"].waitForExistence(timeout: 2.0))

        print(app.debugDescription)
        XCTAssert(app.navigationBars.buttons["Request Notification Authorization"].waitForExistence(timeout: 2.0))
        XCTAssert(app.staticTexts["Weight Measurement"].exists, "It seems that provisional notification authorization didn't work.")

        app.navigationBars.buttons["Request Notification Authorization"].tap()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssert(springboard.alerts.firstMatch.waitForExistence(timeout: 5.0))
        XCTAssert(springboard.alerts.buttons["Allow"].exists)
        springboard.alerts.buttons["Allow"].tap()

        XCTAssert(app.staticTexts.matching(identifier: "Medication").count > 5) // ensure events are scheduled

        app.staticTexts["Weight Measurement"].tap()

        XCTAssert(app.navigationBars.staticTexts["Weight Measurement"].waitForExistence(timeout: 2.0))
        XCTAssert(app.staticTexts["Title, Weight Measurement"].exists)
        XCTAssert(app.staticTexts["Body, Take a weight measurement every day."].exists)
        XCTAssert(app.staticTexts["Category, edu.stanford.spezi.scheduler.notification.category.measurement"].exists)
        XCTAssert(app.staticTexts["Thread, edu.stanford.spezi.scheduler.notification.taskId.test-measurement"].exists)

        XCTAssert(app.staticTexts["Sound, Yes"].exists)
        XCTAssert(app.staticTexts["Interruption, timeSensitive"].exists)

        XCTAssert(app.staticTexts["Type, Calendar"].exists)

        XCTAssert(app.staticTexts["Identifier, edu.stanford.spezi.scheduler.notification.task.test-measurement"].exists)

        XCTAssert(app.staticTexts["Next Trigger, in 10 seconds"].waitForExistence(timeout: 60))


        let notification = springboard.otherElements["Notification"].descendants(matching: .any)["NotificationShortLookView"]
        XCTAssert(notification.waitForExistence(timeout: 30))
        XCTAssert(notification.staticTexts["Weight Measurement"].exists)
        XCTAssert(notification.staticTexts["Take a weight measurement every day."].exists)
        notification.tap()

        XCTAssert(app.navigationBars.buttons["Pending Notifications"].waitForExistence(timeout: 2.0))
        app.navigationBars.buttons["Pending Notifications"].tap()

        XCTAssert(app.staticTexts["Medication"].firstMatch.waitForExistence(timeout: 2.0))
        app.staticTexts["Medication"].firstMatch.tap()


        XCTAssert(app.navigationBars.staticTexts["Medication"].waitForExistence(timeout: 2.0))
        XCTAssert(app.staticTexts["Title, Medication"].exists)
        XCTAssert(app.staticTexts["Body, Take your medication"].exists)
        XCTAssert(app.staticTexts["Category, edu.stanford.spezi.scheduler.notification.category.medication"].exists)
        XCTAssert(app.staticTexts["Thread, edu.stanford.spezi.scheduler.notification.taskId.test-medication"].exists)

        XCTAssert(app.staticTexts["Sound, Yes"].exists)
        XCTAssert(app.staticTexts["Interruption, timeSensitive"].exists)

        XCTAssert(app.staticTexts["Type, Interval"].exists)
        XCTAssert(app.staticTexts["Next Trigger, in 1 week"].waitForExistence(timeout: 60))
    }
}
