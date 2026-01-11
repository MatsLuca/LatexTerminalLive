import AppKit
import SwiftUI
import ScreenCaptureKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotkeyManager: HotkeyManager?
    private var screenCaptureManager = ScreenCaptureManager()
    private var overlayWindow: OverlayWindow?
    private var overlayViewModel = OverlayViewModel()
    private var settingsWindow: NSWindow?
    
    private var settings = SettingsManager()
    private var cancellables = Set<AnyCancellable>()
    private var liveModeTimer: Timer?
    private var isManuallyHidden = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force app to be an accessory (menu bar only)
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusItem()
        
        // Check for Accessibility permissions (required for global hotkeys)
        checkAccessibilityPermissions()
        
        // Screen capture permissions
        screenCaptureManager.requestPermissions { _ in }
        
        self.setupHotkey()
        
        // Observe Settings for Live Mode
        settings.$isLiveModeEnabled
            .sink { [weak self] isEnabled in
                if isEnabled {
                    self?.isManuallyHidden = false
                    self?.startLiveMode()
                } else {
                    self?.stopLiveMode()
                }
            }
            .store(in: &cancellables)
            
        settings.$updateInterval
            .sink { [weak self] _ in
                // Restart timer if running to apply new interval
                if self?.settings.isLiveModeEnabled == true {
                    self?.startLiveMode()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Prefer custom icon asset if exists
            if let customIcon = NSImage(named: "MenuBarIcon") {
                customIcon.isTemplate = true
                customIcon.size = NSSize(width: 18, height: 18)
                button.image = customIcon
            } else if let icon = NSImage(systemSymbolName: "sum", accessibilityDescription: "LatexTerminalLive") {
                icon.isTemplate = true
                button.image = icon
            } else {
                button.title = "Σ"
            }
            button.isEnabled = true
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "LatexTerminalLive v1.0", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Force Capture", action: #selector(triggerManualCapture), keyEquivalent: "l"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc private func triggerManualCapture() {
        handleHotkey()
    }
    
    private func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !isTrusted {
            print("⚠️ WARNING: Global Hotkeys will NOT work until you grant Accessibility permissions in System Settings!")
        }
    }
    
    private func setupHotkey() {
        hotkeyManager = HotkeyManager(
            onTrigger: { [weak self] in self?.handleHotkey() },
            onSettings: { [weak self] in self?.openSettings() }
        )
    }
    
    private var trackedWindowID: CGWindowID?
    private var trackingTimer: Timer?
    
    // ... setupStatusItem and other methods ...
    
    private func handleHotkey() {
        print("DEBUG: Hotkey Handler triggered")
        
        if let window = overlayWindow, window.isVisible {
            isManuallyHidden = true
            stopTracking()
            window.orderOut(nil)
            print("DEBUG: Overlay manually hidden")
            return
        }
        
        isManuallyHidden = false
        performCapture(isAutoUpdate: false)
    }
    
    private func performCapture(isAutoUpdate: Bool) {
        if isAutoUpdate && isManuallyHidden {
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        Task {
            let (items, windowFrame, windowID, theme) = await screenCaptureManager.captureGhosttyAndProcess()
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            await MainActor.run {
                self.settings.lastProcessingTime = duration
                
                if items.isEmpty {
                    print("DEBUG: No items found to display")
                    return
                }
                
                self.trackedWindowID = windowID
                showOverlay(with: items, over: windowFrame, theme: theme)
                startTracking()
            }
        }
    }
    
    private func startTracking() {
        trackingTimer?.invalidate()
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateOverlayPosition()
        }
    }
    
    private func stopTracking() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        trackedWindowID = nil
    }
    
    private func updateOverlayPosition() {
        guard let windowID = trackedWindowID, let overlay = overlayWindow, overlay.isVisible else {
            stopTracking()
            return
        }
        
        Task {
            let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            if let window = content?.windows.first(where: { $0.windowID == windowID }) {
                await MainActor.run {
                    let appKitFrame = CoordinateTransform.sckFrameToAppKit(window.frame)
                    if overlay.frame != appKitFrame {
                        overlay.setFrame(appKitFrame, display: true)
                    }
                    
                    // Maintain Z-order: Only pull to front if Ghostty is the active app
                    // This allows other apps to cover the overlay when they are in front.
                    if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.mitchellh.ghostty" {
                        overlay.orderFrontRegardless()
                    }
                }
            } else {
                await MainActor.run { stopTracking(); overlay.orderOut(nil) }
            }
        }
    }
    
    private func showOverlay(with items: [RecognizedTextItem], over frame: CGRect, theme: AppTheme) {
        let appKitFrame = CoordinateTransform.sckFrameToAppKit(frame)
        
        // Update the persistent ViewModel instead of recreating the view
        overlayViewModel.update(items: items, theme: theme, frame: appKitFrame)
        
        if overlayWindow == nil {
            let view = OverlayView(viewModel: overlayViewModel, settings: settings)
            let hostingView = NSHostingView(rootView: view)
            overlayWindow = OverlayWindow(contentView: hostingView)
        }
        
        overlayWindow?.show(over: appKitFrame)
        
        // Only force to front if Ghostty is active
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.mitchellh.ghostty" {
            overlayWindow?.orderFrontRegardless()
        }
    }
    
    private func startLiveMode() {
        print("DEBUG: Starting Live Mode with interval \(settings.updateInterval)")
        stopLiveMode()
        liveModeTimer = Timer.scheduledTimer(withTimeInterval: settings.updateInterval, repeats: true) { [weak self] _ in
            // Only trigger if we are not already tracking/showing something?
            // "Live Mode" implies we keep scanning.
            // If the user moves the window, tracking handles it.
            // But we need to refresh the CONTENT.
            // So yes, re-capture.
            // self?.triggerManualCapture() // This would toggle!
            self?.performCapture(isAutoUpdate: true)
        }
    }
    
    private func stopLiveMode() {
        print("DEBUG: Stopping Live Mode")
        liveModeTimer?.invalidate()
        liveModeTimer = nil
    }
    
    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(settings: settings)
            let hostingController = NSHostingController(rootView: settingsView)
            
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Preferences"
            window.styleMask = [.titled, .closable]
            window.center()
            window.isReleasedWhenClosed = false
            
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
