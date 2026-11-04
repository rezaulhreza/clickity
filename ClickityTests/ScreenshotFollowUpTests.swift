//
//  ScreenshotFollowUpTests.swift
//  ClickityTests
//

import Foundation
import Testing
@testable import Clickity

struct ScreenshotFollowUpTests {

    @Test(arguments: [
        ("clickity://capture-area?then=copy", ScreenshotFollowUp.copy),
        ("clickity://capture-window?then=save", .save),
        ("clickity://capture-screen?other=1&then=pin", .pin)
    ])
    func readsThen(link: String, expected: ScreenshotFollowUp) throws {
        #expect(ScreenshotFollowUp(url: try #require(URL(string: link))) == expected)
    }

    @Test(arguments: ["clickity://capture-area", "clickity://capture-area?then=upload", "clickity://capture-area?then="])
    func opensTheCardWithoutAKnownThen(link: String) throws {
        #expect(ScreenshotFollowUp(url: try #require(URL(string: link))) == nil)
    }
}
