//
//  LoginItemTests.swift
//  ClickityTests
//

import ServiceManagement
import Testing
@testable import Clickity

struct LoginItemTests {

    @Test func theSwitchFollowsTheSystemsStatus() {
        #expect(LoginItem.State(.enabled) == .on)
        #expect(LoginItem.State(.notRegistered) == .off)
        #expect(LoginItem.State(.notFound) == .off)
        #expect(LoginItem.State(.requiresApproval) == .needsApproval)
    }

    @Test func aLoginItemWaitingForApprovalShowsAsOn() {
        #expect(LoginItem.State.needsApproval.isOn)
        #expect(LoginItem.State.on.isOn)
        #expect(!LoginItem.State.off.isOn)
    }
}
