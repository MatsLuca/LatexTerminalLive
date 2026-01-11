import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    private var screenCaptureManager = ScreenCaptureManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("LatexTerminalLive started")
        
        // Request permissions early
        screenCaptureManager.requestPermissions { granted in
            if granted {
                print("Permissions granted")
                self.setupHotkey()
            } else {
                print("Permissions denied")
            }
        }
    }
    
    private func setupHotkey() {
        hotkeyManager = HotkeyManager { [weak self] in
            self?.handleHotkey()
        }
    }
    
    private func handleHotkey() {
        print("Hotkey triggered!")
        Task {
            await screenCaptureManager.captureGhostty()
        }
    }
}
