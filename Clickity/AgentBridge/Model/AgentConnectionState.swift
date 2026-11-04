//
//  AgentConnectionState.swift
//  Clickity
//

/// Whether an agent's settings list Clickity.
nonisolated enum AgentConnectionState: Equatable, Sendable {
    case notInstalled
    case notConnected
    case connected

    /// Clickity's entry is there but differs from what Clickity would write now, e.g. the app moved.
    case outdated
}
