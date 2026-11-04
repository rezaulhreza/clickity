//
//  OpenAtLoginToggle.swift
//  Clickity
//

import ServiceManagement
import SwiftUI

/// The General tab's Open at Login switch, and what to do when macOS asks for approval.
struct OpenAtLoginToggle: View {
    @State private var loginItem = LoginItem()

    var body: some View {
        Toggle(isOn: Binding(get: { loginItem.state.isOn }, set: loginItem.setOn)) {
            Text("Open at Login")
            if loginItem.state == .needsApproval {
                Text("Allow Clickity in System Settings → General → Login Items & Extensions.")
            }
        }
        if loginItem.state == .needsApproval {
            Button("Open Login Items Settings…") {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }
}
