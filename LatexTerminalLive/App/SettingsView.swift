import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    
    var body: some View {
        TabView {
            // General Settings Tab
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Live Mode Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.yellow)
                                Text("Live Mode")
                                    .font(.headline)
                            }
                            
                            Toggle("Auto-Update (Live)", isOn: $settings.isLiveModeEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                            
                            if settings.isLiveModeEnabled {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Update Interval")
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(settings.updateInterval, specifier: "%.1f")s")
                                            .foregroundColor(.secondary)
                                            .font(.system(.subheadline, design: .monospaced))
                                    }
                                    Slider(value: $settings.updateInterval, in: 0.5...5.0, step: 0.5)
                                }
                                .padding(.leading, 4)
                            }
                            
                            // Explanation Text
                            VStack(alignment: .leading, spacing: 6) {
                                Text("How it works:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                
                                Text("OCR: Captures screen and uses AI to detect LaTeX. Optimized for speed and precision.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                        
                        // Appearance Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "paintbrush.fill")
                                    .foregroundColor(.purple)
                                Text("Appearance")
                                    .font(.headline)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Font Size (\(Int(settings.fontSize))px)")
                                    .font(.subheadline)
                                Slider(value: $settings.fontSize, in: 12...64, step: 2)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Opacity (\(Int(settings.overlayOpacity * 100))%)")
                                    .font(.subheadline)
                                Slider(value: $settings.overlayOpacity, in: 0.3...1.0)
                            }
                            
                            Divider()
                            
                            // Color Selection
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle("Use Custom Color", isOn: $settings.useCustomColor)
                                    .toggleStyle(SwitchToggleStyle(tint: .green))
                                
                                if settings.useCustomColor {
                                    ColorPicker("LaTeX Font Color", selection: $settings.latexColor, supportsOpacity: false)
                                        .font(.subheadline)
                                } else {
                                    HStack {
                                        Text("Current Theme:")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text("Adaptive (Auto)")
                                            .font(.subheadline)
                                            .bold()
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                        
                        // Performance Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "gauge.with.needle.fill")
                                    .foregroundColor(.orange)
                                Text("Performance")
                                    .font(.headline)
                            }
                            
                            Toggle("Show Performance Stats", isOn: $settings.showPerformanceStats)
                                .toggleStyle(SwitchToggleStyle(tint: .orange))
                            
                            if settings.showPerformanceStats {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Cycle Duration:")
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(Int(settings.lastProcessingTime * 1000))ms")
                                            .foregroundColor(settings.lastProcessingTime > 0.4 ? .red : (settings.lastProcessingTime > 0.2 ? .yellow : .green))
                                            .font(.system(.subheadline, design: .monospaced))
                                            .bold()
                                    }
                                    
                                    // Visual Progress Bar for Occupancy
                                    let occupancy = min(settings.lastProcessingTime / settings.updateInterval, 1.0)
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("CPU Occupancy")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("\(Int(occupancy * 100))%")
                                                .font(.caption2)
                                                .monospaced()
                                        }
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule().fill(Color.secondary.opacity(0.2))
                                                Capsule()
                                                    .fill(occupancy > 0.8 ? Color.red : (occupancy > 0.5 ? Color.yellow : Color.green))
                                                    .frame(width: geo.size.width * CGFloat(occupancy))
                                            }
                                        }
                                        .frame(height: 6)
                                    }
                                    
                                    Text("Capturing every \(settings.updateInterval, specifier: "%.1f")s. Red area means processing takes almost as long as the interval.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                    }
                    .padding()
                }
                
                Divider()
                
                HStack {
                    Text("LatexTerminalLive v1.2.0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Done") {
                        NSApp.keyWindow?.close()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
            }
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
        }
        .frame(width: 380, height: 500)
    }
}
