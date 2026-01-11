import AppKit
import SwiftUI

class OverlayWindow: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .normal // Same level as terminal to allow being covered
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // Move with spaces and show over fullscreen
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.contentView = contentView
    }
    
    override var canBecomeKey: Bool {
        return false // Stay non-interactive
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
    func show(over frame: CGRect) {
        self.setFrame(frame, display: true)
        if !self.isVisible {
            self.orderFront(nil)
        }
    }
}
