import SwiftUI

struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel
    @ObservedObject var settings: SettingsManager
    
    private let detector = LaTeXDetector()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.clear // Essential for ZStack sizing
                
                ForEach(viewModel.items) { item in
                    ForEach(item.mathFragments) { fragment in
                        let width = fragment.boundingBox.width * geometry.size.width
                        let height = fragment.boundingBox.height * geometry.size.height
                        
                        let xOffset = fragment.boundingBox.origin.x * geometry.size.width
                        let yOffset = (1.0 - fragment.boundingBox.origin.y - fragment.boundingBox.size.height) * geometry.size.height
                        
                        // Layer 1: The Mask (Darks out original text)
                        // Using the detected terminal background color
                        Rectangle()
                            .fill(viewModel.theme.backgroundColor)
                            .frame(width: width + 8, height: height + 4) // Slightly larger to ensure coverage
                            .blur(radius: 2) // Soften edges for better blending
                            .offset(x: xOffset - 4, y: yOffset - 2)
                        
                        // Layer 2: The Render (KaTeX)
                        let renderHeight = height * 2.5 // More room for tall operators
                        let renderYOffset = yOffset - (renderHeight - height) / 2
                        
                        MathView(
                            latex: fragment.text,
                            fontSize: settings.fontSize,
                            opacity: settings.overlayOpacity,
                            color: settings.useCustomColor ? settings.latexColor : viewModel.theme.foregroundColor
                        )
                        .frame(width: width + 50, height: renderHeight) // Allow generous horizontal bleed for long formulas
                        .offset(x: xOffset - 4, y: renderYOffset) // Align left edge with mask's safety margin
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        // Subtle glow based on foreground color
                        .shadow(color: (settings.useCustomColor ? settings.latexColor : viewModel.theme.foregroundColor).opacity(0.15), radius: 4, x: 0, y: 0)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.items.count)
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottomTrailing) {
            if settings.showPerformanceStats {
                Text("\(String(format: "%.1f", settings.currentCPUUsage))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(4)
                    .padding(8)
            }
        }
    }
}
