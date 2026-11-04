//
//  LoginItem.swift
//  Clickity
//

import Foundation
import OSLog
import ServiceManagement

/// Whether Clickity opens when the user logs in, through the system's Login Items.
@MainActor
@Observable
final class LoginItem {

    /// What the Open at Login switch shows for a login item status.
    nonisolated enum State: Equatable, Sendable {
        case off
        case on
        /// Registered, but the user has to allow it in System Settings → General → Login Items & Extensions.
        case needsApproval

        init(_ status: SMAppService.Status) {
            switch status {
            case .enabled: self = .on
            case .requiresApproval: self = .needsApproval
            default: self = .off
            }
        }

        /// Whether the switch is on: a login item waiting for approval is on, since the user asked for it.
        var isOn: Bool { self != .off }
    }

    private(set) var state: State
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Clickity", category: "LoginItem")

    init() {
        state = State(SMAppService.mainApp.status)
    }

    func setOn(_ isOn: Bool) {
        do {
            if isOn {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Couldn't change Open at Login: \(error.localizedDescription)")
        }
        // The system's status is the truth, whether or not the change went through
        state = State(SMAppService.mainApp.status)
    }
}
