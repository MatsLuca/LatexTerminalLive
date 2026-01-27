import AppKit
import ApplicationServices
import OSLog

class AutomationManager {
    static let shared = AutomationManager()
    private let logger = Logger(subsystem: "com.antigravity.LatexTerminalLive", category: "Automation")
    
    /// Extracts text from the frontmost application using Accessibility API.
    /// Returns nil if AX extraction fails.
    /// Note: Clipboard fallback is intentionally DISABLED for Ghostty to prevent auto-scrolling issues.
    func extractTextSilently() async -> String? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Try silent extraction via Accessibility API
        if let text = await extractViaAccessibility() {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            if duration > 0.1 {
                DebugLog.automation("AX Extraction success: \(text.count) chars in \(String(format: "%.3f", duration))s")
            }
            return text
        }
        
        return nil
    }
    
    private func extractViaAccessibility() async -> String? {
        let apps = NSWorkspace.shared.runningApplications
        
        // 1. Target Ghostty specifically (Handle multiple processes check)
        let ghosttyApps = apps.filter { $0.bundleIdentifier?.contains("ghostty") == true || $0.localizedName?.lowercased().contains("ghostty") == true }
        
        if !ghosttyApps.isEmpty {
            DebugLog.automation("Found \(ghosttyApps.count) Ghostty process candidate(s):")
            for app in ghosttyApps {
                DebugLog.automation(" - Name: \(app.localizedName ?? "?"), PID: \(app.processIdentifier), Bundle: \(app.bundleIdentifier ?? "?")")
            }

            // Try each candidate
            for app in ghosttyApps {
                DebugLog.automation("Attempting extraction from PID \(app.processIdentifier)...")
                if let text = extractFromGhostty(app) {
                    DebugLog.automation("Success with PID \(app.processIdentifier)!")
                    return text
                }
            }
        }

        // 2. Generic System-Wide Focused Element Fallback
        DebugLog.automation("Trying Generic System-Wide Fallback...")
        var results: [String] = []
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        
        let res = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        if res == .success {
            let element = focusedElement as! AXUIElement
            let info = getElementInfo(element)
            DebugLog.automation("Generic Fallback: Focused Element Role=\(info.role), Title='\(info.title ?? "")'")
            collectTextElements(in: element, results: &results, depth: 0)
        } else {
             DebugLog.automation("Generic Fallback: Failed to get focused element (Error \(res.rawValue))")
        }

        if results.isEmpty {
            DebugLog.automation("Generic Fallback: No text results found.")
            return nil
        }
        
        // Heuristic: Prefer math-rich or longest text
        let mathRich = results.filter { $0.contains("$") || $0.contains("\\") }
        return mathRich.max(by: { $0.count < $1.count }) ?? results.max(by: { $0.count < $1.count })
    }
    
    /// Specific traversal for Ghostty's AX structure:
    /// AXApplication -> AXWindow (Focused OR Any) -> AXGroup (HostingView) -> AXGroup -> AXTextArea
    private func extractFromGhostty(_ app: NSRunningApplication) -> String? {
        let appRef = AXUIElementCreateApplication(app.processIdentifier)
        var targetWindows: [AXUIElement] = []
        
        // 1. Try Focused Window first
        var focusedWindow: AnyObject?
        if AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success {
            targetWindows.append(focusedWindow as! AXUIElement)
        } else {
             DebugLog.automation("Ghostty: No focused window found. Trying all windows...")
        }

        // 2. If no focused window, try kAXWindowsAttribute
        var windowsRef: AnyObject?
        var axErr = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef)

        // 3. Fallback: If kAXWindowsAttribute fails (e.g. -25204), try kAXChildren
        if axErr != .success {
            DebugLog.automation("Ghostty: kAXWindowsAttribute failed (\(axErr.rawValue)). Trying kAXChildrenAttribute...")
            axErr = AXUIElementCopyAttributeValue(appRef, kAXChildrenAttribute as CFString, &windowsRef)
        }

        if axErr == .success, let children = windowsRef as? [AXUIElement] {
            DebugLog.automation("Ghostty: Found \(children.count) elements via Windows/Children fallback.")

            for child in children {
                // Determine if it's a window (for Children fallback) or just assume it is (for Windows attr)
                let info = getElementInfo(child)
                // Only consider Windows or StandardWindows
                if info.role == "AXWindow" || info.role == "AXStandardWindow" {
                    if !targetWindows.contains(where: { $0 == child }) {
                        targetWindows.append(child)
                    }
                }
            }
        } else {
             DebugLog.automation("Ghostty: Failed to get Windows or Children. Error: \(axErr.rawValue)")
        }

        if targetWindows.isEmpty {
             DebugLog.automation("Ghostty: No windows found at all (Focused or List).")
        }

        // 4. Search in all target windows
        for (i, window) in targetWindows.enumerated() {
             DebugLog.automation("Searching Window \(i+1)...")
            if let text = findTextAreaValue(in: window, depth: 0) {
                return text
            }
        }
        
        return nil
    }
    
    private func findTextAreaValue(in element: AXUIElement, depth: Int) -> String? {
        if depth > 10 { return nil }
        
        let info = getElementInfo(element)
        
        // DEBUG: Specific Logging for Ghostty Traversal
        // Log everything to establish the tree structure
        DebugLog.automation("Traversing Ghostty: Depth=\(depth) Role=\(info.role) Title='\(info.title ?? "nil")'")
        
        // Check if current node is the TextArea
        if info.role == "AXTextArea" {
            let text = info.value ?? ""
            // Only return if it has meaningful content
            if !text.isEmpty && !text.allSatisfy({ $0.isWhitespace }) {
                DebugLog.automation("✅ Found valid AXTextArea content (\(text.count) chars)")
                DebugLog.automation("Content sample: \(text.prefix(100).replacingOccurrences(of: "\n", with: "\\n"))")
                return text
            } else if info.value != nil {
                 DebugLog.automation("Found AXTextArea but it was empty/whitespace.")
            }
        }
        
        // Recurse into children
        var children: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
           let kids = children as? [AXUIElement] {
            for kid in kids {
                if let found = findTextAreaValue(in: kid, depth: depth + 1) {
                    return found
                }
            }
        }
        
        return nil
    }
    
    private func collectTextElements(in element: AXUIElement, results: inout [String], depth: Int) {
        if depth > 12 { return }
        
        let info = getElementInfo(element)
        
        // Logic for generic apps: Prefer Value, then Description (if long), then Title (if StaticText)
        var text: String?
        if let v = info.value, !v.isEmpty { text = v }
        else if let d = info.desc, d.count > 50 { text = d }
        else if let t = info.title, !t.isEmpty, info.role == "AXStaticText" { text = t }
        
        if let t = text {
            results.append(t)
        }
        
        var children: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
           let childrenArr = children as? [AXUIElement] {
            for child in childrenArr {
                collectTextElements(in: child, results: &results, depth: depth + 1)
            }
        }
    }
    
    // Helper structure
    private struct ElementInfo {
        let role: String
        let title: String?
        let desc: String?
        let value: String?
    }
    
    private func getElementInfo(_ element: AXUIElement) -> ElementInfo {
        var role: AnyObject?
        var title: AnyObject?
        var desc: AnyObject?
        var value: AnyObject?
        
        // We ignore errors here and just use what we get
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &desc)
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        return ElementInfo(
            role: (role as? String) ?? "Unknown",
            title: title as? String,
            desc: desc as? String,
            value: value as? String
        )
    }
    
}

