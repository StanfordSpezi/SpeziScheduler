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
        
        app.assert(tasks: 1, events: 1, fulfilledEvents: 0)
        
        app.buttons["Fulfill Event"].tap()
        app.assert(tasks: 1, events: 1, fulfilledEvents: 1)
        
        app.buttons["Unfulfull Event"].tap()
        app.assert(tasks: 1, events: 1, fulfilledEvents: 0)
        
        app.buttons["Add Task"].tap()
        app.assert(tasks: 2, events: 3, fulfilledEvents: 0)
        
        app.buttons["Fulfill Event"].tap()
        app.buttons["Fulfill Event"].tap()
        app.buttons["Fulfill Event"].tap()
        app.buttons["Fulfill Event"].tap()
        app.assert(tasks: 2, events: 3, fulfilledEvents: 3)
        
        
        app.terminate()
        app.launch()
        
        app.assert(tasks: 2, events: 3, fulfilledEvents: 3)
        
        app.buttons["Unfulfull Event"].tap()
        app.assert(tasks: 2, events: 3, fulfilledEvents: 2)
        
        
        app.terminate()
        app.launch()
        
        app.assert(tasks: 2, events: 3, fulfilledEvents: 2)
        
        app.buttons["Fulfill Event"].tap()
        app.buttons["Unfulfull Event"].tap()
        app.assert(tasks: 2, events: 3, fulfilledEvents: 2)
        
        app.buttons["Add Task"].tap()
        app.assert(tasks: 3, events: 5, fulfilledEvents: 2)
        
        app.buttons["Fulfill Event"].tap()
        app.buttons["Fulfill Event"].tap()
        app.buttons["Fulfill Event"].tap()
        app.assert(tasks: 3, events: 5, fulfilledEvents: 5)
        
        
        app.terminate()
        app.launch()
        
        app.assert(tasks: 3, events: 5, fulfilledEvents: 5)
    }
}


extension XCUIApplication {
    fileprivate func assert(tasks: Int, events: Int, fulfilledEvents: Int) {
        XCTAssert(staticTexts["\(tasks) Tasks"].waitForExistence(timeout: 2))
        XCTAssert(staticTexts["\(events) Events"].waitForExistence(timeout: 2))
        XCTAssert(staticTexts["Fulfilled \(fulfilledEvents) Events"].waitForExistence(timeout: 2))
    }
}
