//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import XCTest
import XCTestExtensions


class TestAppUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        continueAfterFailure = false
        
        let app = XCUIApplication()
        app.deleteAndLaunch(withSpringboardAppName: "TestApp")
    }
    
    
    func testSchedulerLocalStorage() throws {
        let app = XCUIApplication()
        
        XCTAssert(app.staticTexts["Scheduler"].waitForExistence(timeout: 2))
        
        app.assert(tasks: 1, events: 1, pastEvents: 1, fulfilledEvents: 0)
        
        app.buttons["Fulfill Event"].tap()
        app.assert(tasks: 1, events: 1, pastEvents: 1, fulfilledEvents: 1)
        
        app.buttons["Unfulfull Event"].tap()
        app.assert(tasks: 1, events: 1, pastEvents: 1, fulfilledEvents: 0)
        
        app.buttons["Add Task"].tap()
        app.assert(tasks: 2, events: 3, fulfilledEvents: 0)
        
        app.buttons["Fulfill Event"].tap()
        app.buttons["Fulfill Event"].tap()
        app.buttons["Fulfill Event"].tap()
        app.buttons["Fulfill Event"].tap()
        app.assert(tasks: 2, events: 3, pastEvents: 3, fulfilledEvents: 3)
        
        
        app.terminate()
        app.launch()
        
        app.assert(tasks: 2, events: 3, pastEvents: 3, fulfilledEvents: 3)
        
        app.buttons["Unfulfull Event"].tap()
        app.assert(tasks: 2, events: 3, pastEvents: 3, fulfilledEvents: 2)
        
        
        app.terminate()
        app.launch()
        
        app.assert(tasks: 2, events: 3, pastEvents: 3, fulfilledEvents: 2)
        
        app.buttons["Fulfill Event"].tap()
        app.buttons["Unfulfull Event"].tap()
        app.assert(tasks: 2, events: 3, pastEvents: 3, fulfilledEvents: 2)
        
        app.buttons["Fulfill Event"].tap()
        app.assert(tasks: 2, events: 3, pastEvents: 3, fulfilledEvents: 3)
        
        
        app.terminate()
        app.launch()
        
        app.assert(tasks: 2, events: 3, pastEvents: 3, fulfilledEvents: 3)
    }
    
    
    func testSchedulerNotifications() throws {
        let app = XCUIApplication()
        
        XCTAssert(app.staticTexts["Scheduler"].waitForExistence(timeout: 2))
        
        app.assert(tasks: 1, events: 1, pastEvents: 1, fulfilledEvents: 0)
        
        app.buttons["Request Notification Permissions"].tap()
        
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alertAllowButton = springboard.buttons["Allow"]
        if alertAllowButton.waitForExistence(timeout: 5) {
            alertAllowButton.tap()
        } else {
            print("Did not observe the notification permissions alert. Permissions might have already been provided.")
        }
        
        app.buttons["Add Notification Task"].tap()
        app.assert(tasks: 2, events: 2, pastEvents: 1, fulfilledEvents: 0)
        
        springboard.activate()
        XCTAssert(springboard.wait(for: .runningForeground, timeout: 2))
        
        let notification = springboard.otherElements["Notification"].descendants(matching: .any)["NotificationShortLookView"]
        XCTAssert(notification.waitForExistence(timeout: 120))
        notification.tap()
        
        XCTAssert(app.wait(for: .runningForeground, timeout: 2))
        
        app.assert(tasks: 2, events: 2, pastEvents: 2, fulfilledEvents: 0)
        
        XCTAssert(app.staticTexts["Scheduler"].waitForExistence(timeout: 2))
        app.buttons["Fulfill Event"].tap()
        app.buttons["Fulfill Event"].tap()
        app.assert(tasks: 2, events: 2, pastEvents: 2, fulfilledEvents: 2)
    }
}


extension XCUIApplication {
    // swiftlint:disable:next function_default_parameter_at_end
    fileprivate func assert(tasks: Int, events: Int, pastEvents: Int? = nil, fulfilledEvents: Int) {
        XCTAssert(staticTexts["\(tasks) Tasks"].waitForExistence(timeout: 2))
        XCTAssert(staticTexts["\(events) Events"].waitForExistence(timeout: 2))
        if let pastEvents {
            XCTAssert(staticTexts["\(pastEvents) Past Events"].waitForExistence(timeout: 2))
        }
        XCTAssert(staticTexts["Fulfilled \(fulfilledEvents) Events"].waitForExistence(timeout: 2))
    }
}
