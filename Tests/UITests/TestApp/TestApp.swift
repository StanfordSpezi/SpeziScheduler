//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziScheduler
import SwiftUI


@main
struct UITestsApp: App {
    @UIApplicationDelegateAdaptor(TestAppDelegate.self)
    var appDelegate
    
    
    var body: some Scene {
        WindowGroup {
            TabView {
                ScheduleView()
                    .tabItem {
                        Label("Schedule", systemImage: "list.clipboard.fill")
                    }
                VStack {
                    ContentView()
                }
                    .tabItem {
                        Label("Legacy", systemImage: "moon.zzz")
                    }
            }
                .spezi(appDelegate)
        }
    }
}
