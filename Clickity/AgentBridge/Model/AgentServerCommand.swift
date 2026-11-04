//
//  AgentServerCommand.swift
//  Clickity
//

/// How an agent starts Clickity's MCP server: the app's own binary with ``AgentBridgeClient/argument``,
/// and the token in its environment.
nonisolated struct AgentServerCommand: Equatable, Sendable {
    var executable: String
    var token: String

    /// The server's name in every agent's settings; Clickity only ever touches entries with this name.
    static let serverName = "clickity"

    static let tokenVariable = "CLICKITY_BRIDGE_TOKEN"
}
