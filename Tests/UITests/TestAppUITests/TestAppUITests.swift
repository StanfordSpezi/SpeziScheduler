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
    private var uses12HourClock: Bool {
        switch Locale.current.hourCycle {
        case .zeroToEleven, .oneToTwelve:
            true
        case .zeroToTwentyThree, .oneToTwentyFour:
            false
        @unknown default:
            true // just assume it's running in the US
        }
    }
    
    func sleep(for duration: Duration) {
        usleep(UInt32(duration.timeInterval * 1000000))
    }
    
    
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
        
        app.swipeUp()
        
        XCTAssert(app.staticTexts["Social Support Questionnaire"].waitForExistence(timeout: 2.0))
        XCTAssert(app.staticTexts["Questionnaire"].exists)
        if uses12HourClock {
            XCTAssert(app.staticTexts["4:00 PM"].exists)
        } else {
            XCTAssert(app.staticTexts["16:00"].exists)
        }

        XCTAssert(app.buttons["More Information"].exists)
        app.buttons.matching(identifier: "More Information").element(boundBy: 1).tap()

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
        app.buttons["Complete Enter Lab Results"].tap()
        
        goToTab("Notifications")

        XCTAssert(app.staticTexts["Pending Notifications"].waitForExistence(timeout: 2.0))

        XCTAssert(app.navigationBars.buttons["Request Notification Authorization"].waitForExistence(timeout: 2.0))
        XCTAssert(app.staticTexts["Weight Measurement"].exists, "It seems that provisional notification authorization didn't work.")

        app.navigationBars.buttons["Request Notification Authorization"].tap()

        app.confirmNotificationAuthorization()
        
        sleep(for: .seconds(0.5))
        XCTAssertGreaterThan(app.staticTexts.matching(identifier: "Medication").count, 3) // ensure events are scheduled

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
            nextTrigger: "in 6 days, 23 hours",
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
        
        app.goToTab(.notifications)

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
        app.goToTab(.schedule)
        app.buttons["Complete Enter Lab Results"].tap()
        sleep(for: .seconds(1))
        app.goToTab(.notifications)
        
        app.staticTexts["Enter Lab Results"].firstMatch.tap()

        XCTAssert(app.navigationBars.staticTexts["Enter Lab Results"].waitForExistence(timeout: 2.0))
        app.staticTexts.matching(
            NSPredicate(format: #"identifier MATCHES '.*edu\.stanford\.spezi\.scheduler\.notification\.event\.enter-lab-results\..*'"#)
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
    
    
    @MainActor
    func testShadowedOutcomesHandlingWhenReRegisteringSameTask() throws {
        let app = XCUIApplication()
        app.deleteAndLaunch(withSpringboardAppName: "TestApp")

        XCTAssert(app.wait(for: .runningForeground, timeout: 2.0))
        
        let menuButton = app.buttons["Extra Tests"]
        XCTAssert(menuButton.waitForExistence(timeout: 2))
        menuButton.tryToTapReallySoftlyMaybeThisWillMakeItWork()
        let testCaseButton = app.buttons["Shadowed Outcomes"]
        XCTAssert(testCaseButton.waitForExistence(timeout: 2))
        testCaseButton.tap()
        
        XCTAssertTrue(app.staticTexts["Passed"].waitForExistence(timeout: 2))
    }
    
    
    @MainActor
    func testObserveOutcomes() throws {
        let app = XCUIApplication()
        app.deleteAndLaunch(withSpringboardAppName: "TestApp")

        XCTAssert(app.wait(for: .runningForeground, timeout: 2.0))
        
        let menuButton = app.buttons["Extra Tests"]
        XCTAssert(menuButton.waitForExistence(timeout: 2))
        menuButton.tryToTapReallySoftlyMaybeThisWillMakeItWork()
        let testCaseButton = app.buttons["Observe New Outcomes"]
        XCTAssert(testCaseButton.waitForExistence(timeout: 2))
        testCaseButton.tap()
        
        XCTAssert(app.staticTexts["did trigger, false"].waitForExistence(timeout: 2))
        let completeButton = app.otherElements["ObserveNewOutcomesView"].buttons["Complete"].firstMatch
        completeButton.tap()
        XCTAssert(app.staticTexts["did trigger, false"].waitForNonExistence(timeout: 2))
        XCTAssert(app.staticTexts["did trigger, true"].waitForExistence(timeout: 2))
        XCTAssert(completeButton.waitForNonExistence(timeout: 2))
    }
    
    
    @MainActor
    func testExplicitNotificationTime() throws {
        // What we test for here is that, when we define a Task with an explicit notificationTime,
        // the start date of the task's occurrences and the time for which the notifications are scheduled,
        // are both correct (and, importantly, different from each other!).
        // In this case, we have a task that is scheduled for midnight, but doesn't want its notification until 00:05.
        // (Note that the reason why these specific times are chosen is to minimise the likelihood the tests accidentally fail;
        // if the test runs while the next occurrence is > 24 hours away the scheduler needs to fall back to a TimeInterval-based
        // trigger, which we can't (easily) decompose into date components.)
        let app = XCUIApplication()
        app.deleteAndLaunch(withSpringboardAppName: "TestApp")
        XCTAssert(app.wait(for: .runningForeground, timeout: 2.0))
        
        XCTAssert(app.collectionViews.staticTexts["Today"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.collectionViews.staticTexts["Timed Walking Test"].exists)
        
        // Part 1: verify the Schedule tab
        app.navigationBars.buttons["More"].tap()
        app.buttons["Date"].tap()
        app.buttons["Tomorrow"].tap()
        XCTAssert(app.collectionViews.staticTexts["Tomorrow"].waitForExistence(timeout: 1))
        XCTAssert(app.collectionViews.staticTexts["Timed Walking Test"].waitForExistence(timeout: 1))
        XCTAssert(app.collectionViews.staticTexts.matching(
            NSPredicate(format: "label MATCHES 'Timed Walking Test, Active Task, In .*, \(uses12HourClock ? "12:00 AM" : "00:00")'")
        ).element.exists)
        
        // Part 2: verify the actual notification scheduling
        app.goToTab(.notifications)
        XCTAssert(app.staticTexts["Pending Notifications"].waitForExistence(timeout: 1))
        app.staticTexts["Timed Walking Test"].firstMatch.tap()
        XCTAssert(app.navigationBars.staticTexts["Timed Walking Test"].waitForExistence(timeout: 1))
        app.assertNotificationDetails(
            identifier: "edu.stanford.spezi.scheduler.notification.task.timed-walking-test",
            title: "Timed Walking Test",
            body: "Walk for 6 minutes!",
            category: "edu.stanford.spezi.scheduler.notification.category.timed-walking-test",
            thread: "edu.stanford.spezi.scheduler.notification",
            sound: true,
            interruption: .timeSensitive,
            type: "Calendar",
            nextTrigger: nil
        )
        XCTAssert(app.staticTexts.matching(
            NSPredicate(format: "label MATCHES 'Date, calendar: .*hour: 0 minute: 5 second: 0.*'")
        ).element.exists, "DateComponents don't match expected time values.")
    }
}


extension XCUIApplication {
    enum Tab: String {
        case schedule = "Schedule"
        case notifications = "Notifications"
    }
    
    func goToTab(_ tab: Tab, line: UInt = #line) {
        let tab = self.tabBars.buttons[tab.rawValue]
        XCTAssert(tab.waitForExistence(timeout: 2.0), line: line)
        tab.tap()
        tab.tap()
    }
}

extension XCUIElement {
    // This is required to work around an apparent XCTest bug when trying to tap e.g. the Health App's Profile button.
    // See also: https://stackoverflow.com/a/33534187
    func tryToTapReallySoftlyMaybeThisWillMakeItWork() {
        if isHittable {
            tap()
        } else {
            coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
