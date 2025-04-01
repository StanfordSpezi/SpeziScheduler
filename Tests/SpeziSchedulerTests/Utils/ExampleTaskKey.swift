//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziScheduler


struct NonTrivialTaskContext: Codable {
    // give it a bunch of fields to maximise the likelihood of something being out of order
    let field0: Int
    let field1: Int
    let field2: Int
    let field3: Int
    let field4: Int
    let field5: Int
    let field6: Int
    let field7: Int
    let field8: Int
    let field9: Int
}


extension Outcome {
    @Property var example: String?
}


extension Task.Context {
    @Property var example: String?
}


extension Task.Context {
    @Property var example2: String = "Hello World"
}

extension Task.Context {
    @Property(coding: .json)
    var nonTrivialExample: NonTrivialTaskContext?
}
