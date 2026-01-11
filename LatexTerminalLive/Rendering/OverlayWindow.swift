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
        self.level = .normal // Back to normal level to stay with terminal
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true // Pass all events to terminal below
        self.contentView = contentView
    }
    
    override var canBecomeKey: Bool {
        return false
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
