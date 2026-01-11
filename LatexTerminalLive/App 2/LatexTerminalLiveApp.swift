import SwiftUI

@main
struct LatexTerminalLiveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // We don't need a main window for this overlay app, 
        // as it will be managed by NSPanel.
        Settings {
            Text("LatexTerminalLive Settings")
                .padding()
        }
    }
}
