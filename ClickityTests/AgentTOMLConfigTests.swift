//
//  AgentTOMLConfigTests.swift
//  ClickityTests
//

import Foundation
import Testing
@testable import Clickity

struct AgentTOMLConfigTests {

    private let command = AgentServerCommand(executable: "/Applications/Clickity.app/Contents/MacOS/Clickity", token: "secret")

    private var table: String {
        """
        [mcp_servers.clickity]
        command = "/Applications/Clickity.app/Contents/MacOS/Clickity"
        args = ["--mcp"]
        env = { CLICKITY_BRIDGE_TOKEN = "secret" }
        """
    }

    @Test func tableIsExactlyWhatCodexReads() {
        #expect(AgentTOMLConfig.table(for: command) == table)
    }

    @Test func connectingToNothingWritesTheTable() throws {
        #expect(try AgentTOMLConfig.connecting(nil, command: command) == table + "\n")
        #expect(try AgentTOMLConfig.connecting("", command: command) == table + "\n")
    }

    @Test func appendingKeepsOtherTablesByteForByte() throws {
        let original = "model = \"gpt\"\n\n[mcp_servers.other]\ncommand = \"x\"\n# note"

        let result = try AgentTOMLConfig.connecting(original, command: command)

        #expect(result == original + "\n\n" + table + "\n")
        #expect(AgentTOMLConfig.disconnecting(result) == original + "\n")
    }

    @Test func connectingThenDisconnectingRestoresAFileThatEndsInANewline() throws {
        let original = "model = \"gpt\"\n\n[profiles.fast]\neffort = \"low\"\n"

        let connected = try AgentTOMLConfig.connecting(original, command: command)

        #expect(connected == original + "\n" + table + "\n")
        #expect(AgentTOMLConfig.disconnecting(connected) == original)
    }

    @Test func reconnectingReplacesOurTableWhereItIs() throws {
        let stale = "[mcp_servers.clickity]\ncommand = \"/old/Clickity\"\nargs = [\"--mcp\"]\n\n[mcp_servers.clickity.env]\nCLICKITY_BRIDGE_TOKEN = \"old\"\n"
        let original = "[a]\nx = 1\n\n" + stale + "\n# the next one\n[b]\ny = 2\n"

        let result = try AgentTOMLConfig.connecting(original, command: command)

        #expect(result == "[a]\nx = 1\n\n" + table + "\n\n# the next one\n[b]\ny = 2\n")
    }

    @Test func disconnectingRemovesTheTableAndItsSubTablesOnly() throws {
        let original = """
            [mcp_servers.other]
            command = "x"

            [mcp_servers.clickity]
            command = "y"

            [mcp_servers.clickity.env]
            A = "1"

            [mcp_servers.recorder]
            command = "z"
            """

        let result = try #require(AgentTOMLConfig.disconnecting(original))

        #expect(result == "[mcp_servers.other]\ncommand = \"x\"\n\n[mcp_servers.recorder]\ncommand = \"z\"")
        #expect(AgentTOMLConfig.removing(original).removed == "[mcp_servers.clickity]\ncommand = \"y\"\n\n[mcp_servers.clickity.env]\nA = \"1\"")
    }

    @Test func disconnectingNeedsNothingWhenClickityIsNotThere() {
        #expect(AgentTOMLConfig.disconnecting("[mcp_servers.other]\ncommand = \"x\"\n") == nil)
    }

    @Test func otherSpellingsOfClickityAreRefused() {
        let forms = [
            "mcp_servers.clickity.command = \"x\"\n",
            "mcp_servers.clickity = { command = \"x\" }\n",
            "[mcp_servers]\nclickity = { command = \"x\" }\n",
            "[mcp_servers]\nclickity.command = \"x\"\n",
            "mcp_servers = { clickity = { command = \"x\" } }\n"
        ]
        for form in forms {
            #expect(throws: AgentTOMLConfig.EditError.unrecognisedEntry) {
                try AgentTOMLConfig.connecting(form, command: command)
            }
        }
    }

    @Test func quotedHeadersAreOurTableToo() throws {
        let result = try AgentTOMLConfig.connecting("[mcp_servers.\"clickity\"]\ncommand = \"x\"\n", command: command)

        #expect(result == table + "\n")
    }

    @Test func similarNamesAreNotRefused() throws {
        let original = "[mcp_servers]\nrecorder = 1\n"

        #expect(try AgentTOMLConfig.connecting(original, command: command) == original + "\n" + table + "\n")
    }

    @Test func quotingEscapesWhatBasicStringsNeed() {
        #expect(AgentTOMLConfig.quoted(#"C:\a "b""#) == #""C:\\a \"b\"""#)
        #expect(AgentTOMLConfig.quoted("a\nb\t\u{1}") == #""a\nb\t\u0001""#)
        #expect(AgentTOMLConfig.quoted("/Users/émile/Clickity") == "\"/Users/émile/Clickity\"")
    }

    @Test func stateTellsConnectedFromOutdatedFromNeither() {
        #expect(AgentTOMLConfig.state(of: "[a]\nx = 1\n\n" + table + "\n", expected: command) == .connected)
        #expect(AgentTOMLConfig.state(of: table.replacing("secret", with: "old"), expected: command) == .outdated)
        #expect(AgentTOMLConfig.state(of: "[a]\nx = 1\n", expected: command) == .notConnected)
    }
}
