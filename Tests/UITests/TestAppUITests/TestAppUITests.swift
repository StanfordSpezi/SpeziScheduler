//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import XCTest
import XCTestExtensions
import XCTSpeziNotifications


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
    func testNotificationScheduling() throws {
        #if os(visionOS)
        throw XCTSkip()
        #endif
        let app = XCUIApplication()
        app.deleteAndLaunch(withSpringboardAppName: "TestApp")

        XCTAssert(app.wait(for: .runningForeground, timeout: 2.0))
        
        let notificationsTabButton = app.buttons.matching(NSPredicate(format: "identifier = 'mail.fill' AND label = 'Notifications'")).firstMatch
        XCTAssert(notificationsTabButton.waitForExistence(timeout: 2.0))
        notificationsTabButton.tap()

        XCTAssert(app.staticTexts["Pending Notifications"].waitForExistence(timeout: 2.0))

        XCTAssert(app.navigationBars.buttons["Request Notification Authorization"].waitForExistence(timeout: 2.0))
        XCTAssert(app.staticTexts["Weight Measurement"].exists, "It seems that provisional notification authorization didn't work.")

        app.navigationBars.buttons["Request Notification Authorization"].tap()

        app.confirmNotificationAuthorization()

        XCTAssertGreaterThan(app.staticTexts.matching(identifier: "Medication").count, 5) // ensure events are scheduled

        app.staticTexts["Weight Measurement"].tap()

        XCTAssert(app.navigationBars.staticTexts["Weight Measurement"].waitForExistence(timeout: 2.0))
        app.assertNotificationDetails(
            identifier: "edu.stanford.spezi.scheduler.notification.task.test-measurement",
            title: "Weight Measurement",
            body: "Take a weight measurement every day.",
            category: "edu.stanford.spezi.scheduler.notification.category.measurement",
            thread: "edu.stanford.spezi.scheduler.notification",
            sound: true,
            interruption: .timeSensitive,
            type: "Calendar",
            nextTrigger: "in 10 seconds",
            nextTriggerExistenceTimeout: 60
        )


        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
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
        app.assertNotificationDetails(
            title: "Medication",
            body: "Take your medication",
            category: "edu.stanford.spezi.scheduler.notification.category.medication",
            thread: "edu.stanford.spezi.scheduler.notification",
            sound: true,
            interruption: .timeSensitive,
            type: "Interval",
            nextTrigger: "in 1 week",
            nextTriggerExistenceTimeout: 60
        )
    }
}
