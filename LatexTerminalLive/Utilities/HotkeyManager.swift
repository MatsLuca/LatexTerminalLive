import AppKit
import Carbon

class HotkeyManager {
    private var eventMonitor: Any?
    private let onTrigger: () -> Void
    private let onSettings: () -> Void
    
    init(onTrigger: @escaping () -> Void, onSettings: @escaping () -> Void) {
        self.onTrigger = onTrigger
        self.onSettings = onSettings
        setupMonitor()
    }
    
    private func setupMonitor() {
        DebugLog.hotkey("Registering monitors for Cmd+Shift+L (Keycode 37)")

        // Global monitor (when app is in background)
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.checkEvent(event, type: "Global")
        }

        // Local monitor (when app is frontmost)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            DebugLog.hotkey("Local Key Event - Code: \(event.keyCode), Modifiers: \(event.modifierFlags)")
            self?.checkEvent(event, type: "Local")
            return event
        }
    }
    
    private func checkEvent(_ event: NSEvent, type: String) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        DebugLog.hotkey("\(type) Key Down: \(event.keyCode), flags: \(flags)")

        // Cmd + Shift + L (KeyCode 37)
        if flags == [.command, .shift] && event.keyCode == 37 {
            DebugLog.hotkey("Toggle Hotkey MATCHED (\(type))!")
            onTrigger()
            return
        }

        // Cmd + Option + , (KeyCode 43)
        // Changed from Shift to Option to avoid conflict with Ghostty/App Settings
        if flags == [.command, .option] && event.keyCode == 43 {
            DebugLog.hotkey("Settings Hotkey MATCHED (\(type))!")
            onSettings()
            return
        }
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
