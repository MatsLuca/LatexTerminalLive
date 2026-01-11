import SwiftUI
import Combine

class OverlayViewModel: ObservableObject {
    @Published var items: [RecognizedTextItem] = []
    @Published var theme: AppTheme = AppTheme(backgroundColor: .black, foregroundColor: .white)
    @Published var windowFrame: CGRect = .zero
    
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
        
        // Deep compare theme and items count to avoid redundant animations
        let itemsChanged = stabilizedItems.map { $0.id } != self.items.map { $0.id }
        let themeChanged = theme.backgroundColor != self.theme.backgroundColor ||
                           theme.foregroundColor != self.theme.foregroundColor
        
        if itemsChanged || themeChanged || self.windowFrame != frame {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.items = stabilizedItems
                self.theme = theme
                self.windowFrame = frame
            }
        }
    }
}
