import SwiftUI
import Combine

class OverlayViewModel: ObservableObject {
    @Published var items: [RecognizedTextItem] = []
    @Published var theme: AppTheme = AppTheme(backgroundColor: .black, foregroundColor: .white)
    @Published var windowFrame: CGRect = .zero
    @Published var copiedId: UUID? = nil
    
    func update(items newItems: [RecognizedTextItem], theme: AppTheme, frame: CGRect) {
        // Build the final list of items, preserving stability for existing ones
        var stabilizedItems: [RecognizedTextItem] = []
        
        for newItem in newItems {
            // Find an existing item that is "equal" (within tolerance)
            if let existing = self.items.first(where: { $0 == newItem }) {
                // Keep the existing one to preserve its stable ID
                stabilizedItems.append(existing)
            } else {
                // It's genuinely new or moved too much
                stabilizedItems.append(newItem)
            }
        }
        
        let itemsChanged = stabilizedItems.map { $0.id } != self.items.map { $0.id }
        let themeChanged = theme.backgroundColor != self.theme.backgroundColor ||
                           theme.foregroundColor != self.theme.foregroundColor
        
        if itemsChanged || themeChanged || self.windowFrame != frame {
            withAnimation(.easeInOut(duration: Constants.UI.overlayAnimationDuration)) {
                self.items = stabilizedItems
                self.theme = theme
                self.windowFrame = frame
            }
        }
    }
    
    func triggerCopiedFeedback(for id: UUID) {
        withAnimation(.spring(response: Constants.UI.copyFeedbackDuration, dampingFraction: 0.6)) {
            self.copiedId = id
        }

        // Auto-hide feedback after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.UI.copyFeedbackHideDelay) {
            if self.copiedId == id {
                withAnimation(.easeInOut(duration: Constants.UI.copyFeedbackFadeOutDuration)) {
                    self.copiedId = nil
                }
            }
        }
    }
}
