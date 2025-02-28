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
    func testNotificationScheduling() throws { // swiftlint:disable:this function_body_length
        let app = XCUIApplication()
        app.deleteAndLaunch(withSpringboardAppName: "TestApp")
        
        func goToTab(_ name: String, line: UInt = #line) {
            let tab = app.tabBars.buttons[name]
            XCTAssert(tab.waitForExistence(timeout: 2.0), line: line)
            tab.tap()
        }

        XCTAssert(app.wait(for: .runningForeground, timeout: 2.0))
        
        func checkButtonExists(_ name: String, line: UInt = #line) {
            XCTAssert(app.buttons[name].waitForExistence(timeout: 2), line: line)
        }
        
        checkButtonExists("Complete Measurement")
        checkButtonExists("Complete Questionnaire")
        checkButtonExists("Complete Enter Lab Results")
        
        goToTab("Notifications")

        XCTAssert(app.staticTexts["Pending Notifications"].waitForExistence(timeout: 2.0))

        XCTAssert(app.navigationBars.buttons["Request Notification Authorization"].waitForExistence(timeout: 2.0))
        XCTAssert(app.staticTexts["Weight Measurement"].exists, "It seems that provisional notification authorization didn't work.")

        app.navigationBars.buttons["Request Notification Authorization"].tap()

        app.confirmNotificationAuthorization()

        // Check for Medication notification
        
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
        
        // Check for Weight Measurement notification
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
    
    
    @MainActor
    func testNotificationSchedulingDontNotifyForAlreadyCompletedEvents() throws {
        let app = XCUIApplication()
        app.deleteAndLaunch(withSpringboardAppName: "TestApp")

        XCTAssert(app.wait(for: .runningForeground, timeout: 2.0))
        
        func checkButtonExists(_ name: String, line: UInt = #line) {
            XCTAssert(app.buttons[name].waitForExistence(timeout: 2), line: line)
        }
        
        XCTAssert(app.buttons["Complete Enter Lab Results"].waitForExistence(timeout: 2))
        
        app.goToTab("Notifications")

        XCTAssert(app.staticTexts["Pending Notifications"].waitForExistence(timeout: 2.0))

        XCTAssert(app.navigationBars.buttons["Request Notification Authorization"].waitForExistence(timeout: 2.0))
        XCTAssert(app.staticTexts["Enter Lab Results"].exists, "It seems that provisional notification authorization didn't work.")

        app.staticTexts["Enter Lab Results"].tap()

        XCTAssert(app.navigationBars.staticTexts["Enter Lab Results"].waitForExistence(timeout: 2.0))
        app.assertNotificationDetails(
            identifier: "edu.stanford.spezi.scheduler.notification.task.enter-lab-results",
            title: "Enter Lab Results",
            body: "You should enter Lab Results into the app at least once every 7 days!",
            category: "edu.stanford.spezi.scheduler.notification.category.lab-results",
            thread: "edu.stanford.spezi.scheduler.notification",
            sound: true,
            interruption: .timeSensitive,
            type: "Calendar",
            nextTrigger: "in 10 seconds",
            nextTriggerExistenceTimeout: 60
        )
        
        // Complete the task for today
        app.goToTab("Schedule")
        app.buttons["Complete Enter Lab Results"].tap()
        sleep(1)
        app.goToTab("Notifications")
        
        app.staticTexts["Enter Lab Results"].firstMatch.tap()

        XCTAssert(app.navigationBars.staticTexts["Enter Lab Results"].waitForExistence(timeout: 2.0))
        app.staticTexts.matching(
            NSPredicate(format: #"identifier MATCHES '.*edu\.stanford\.spezi\.scheduler\.notification\.event\.enter-lab-results.*'"#)
        )
        app.assertNotificationDetails(
            // we can't specify the identifier here, since this is now an event-level-scheduled notification, which includes the event's timestamp.
            // we instead assert the identifier above
            identifier: nil,
            title: "Enter Lab Results",
            body: "You should enter Lab Results into the app at least once every 7 days!",
            category: "edu.stanford.spezi.scheduler.notification.category.lab-results",
            thread: "edu.stanford.spezi.scheduler.notification",
            sound: true,
            interruption: .timeSensitive,
            type: "Interval",
            nextTrigger: "in 23 hours, 59 minutes",
            nextTriggerExistenceTimeout: 60
        )
    }
}


extension XCUIApplication {
    func goToTab(_ name: String, line: UInt = #line) {
        let tab = self.tabBars.buttons[name]
        XCTAssert(tab.waitForExistence(timeout: 2.0), line: line)
        tab.tap()
        tab.tap()
    }
}
