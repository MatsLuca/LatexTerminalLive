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
    
    private var mouseMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        checkAccessibilityPermissions()
        screenCaptureManager.requestPermissions { _ in }
        self.setupHotkey()
        
        setupMouseMonitoring()
        
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
                if self?.settings.isLiveModeEnabled == true {
                    self?.startLiveMode()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
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
            print("⚠️ WARNING: Global Hotkeys and Click-to-Copy will NOT work until you grant Accessibility permissions!")
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
    
    private func handleHotkey() {
        if let window = overlayWindow, window.isVisible {
            isManuallyHidden = true
            stopTracking()
            window.orderOut(nil)
            return
        }
        isManuallyHidden = false
        performCapture(isAutoUpdate: false)
    }
    
    private func performCapture(isAutoUpdate: Bool) {
        if isAutoUpdate && isManuallyHidden { return }
        let startTime = CFAbsoluteTimeGetCurrent()
        Task {
            let (items, windowFrame, windowID, theme) = await screenCaptureManager.captureGhosttyAndProcess()
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            await MainActor.run {
                self.settings.lastProcessingTime = duration
                if items.isEmpty { return }
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
        overlayViewModel.update(items: items, theme: theme, frame: appKitFrame)
        
        if overlayWindow == nil {
            let view = OverlayView(viewModel: overlayViewModel, settings: settings)
            let hostingView = NSHostingView(rootView: view)
            overlayWindow = OverlayWindow(contentView: hostingView)
        }
        
        overlayWindow?.show(over: appKitFrame)
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.mitchellh.ghostty" {
            overlayWindow?.orderFrontRegardless()
        }
    }
    
    private func startLiveMode() {
        stopLiveMode()
        liveModeTimer = Timer.scheduledTimer(withTimeInterval: settings.updateInterval, repeats: true) { [weak self] _ in
            self?.performCapture(isAutoUpdate: true)
        }
    }
    
    private func stopLiveMode() {
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
    
    // MARK: - Click-to-Copy Implementation
    
    private func setupMouseMonitoring() {
        // Monitor global mouse clicks. Requires Accessibility permissions.
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleGlobalClick(event)
        }
    }
    
    private func handleGlobalClick(_ event: NSEvent) {
        // 1. Only care if Ghostty is the active app and overlay is visible
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.mitchellh.ghostty",
              let overlay = overlayWindow, overlay.isVisible else { return }
        
        // 2. Get mouse location relative to the overlay window
        let screenPoint = NSEvent.mouseLocation
        let windowFrame = overlay.frame
        
        // Check if click is inside the window at all
        guard windowFrame.contains(screenPoint) else { return }
        
        // 3. Convert to normalized coordinates (0.0 to 1.0)
        // vision coordinates origin is bottom-left, screen coordinates origin is bottom-left.
        let localX = (screenPoint.x - windowFrame.origin.x) / windowFrame.size.width
        let localY = (screenPoint.y - windowFrame.origin.y) / windowFrame.size.height
        let normalizedPoint = CGPoint(x: localX, y: localY)
        
        // 4. Check against all math fragments
        for item in overlayViewModel.items {
            for fragment in item.mathFragments {
                // Fragment boundingBox is also bottom-left (Vision default)
                if fragment.boundingBox.contains(normalizedPoint) {
                    copyToClipboard(fragment.text, id: fragment.id)
                    return // Only handle one click
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String, id: UUID) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Trigger visual feedback in the overlay
        overlayViewModel.triggerCopiedFeedback(for: id)
        print("[AppDelegate] Copied to clipboard: \(text)")
    }
}
