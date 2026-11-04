//
//  URL+ClickityPaths.swift
//  Clickity
//

import Darwin
import Foundation

extension URL {

    /// The user's home folder from the password database, which ignores `$HOME`: a coding agent that
    /// starts Clickity with `--mcp` may have changed it.
    nonisolated static let userHome = URL(filePath: getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory())

    /// Clickity's own folder in Application Support: the saved web script and the agent socket.
    nonisolated static let clickitySupport = userHome
        .appending(path: "Library/Application Support")
        .appending(path: Bundle.main.bundleIdentifier ?? "com.rezaulhreza.Clickity")
}
