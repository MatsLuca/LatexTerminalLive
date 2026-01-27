import Combine
import AppKit
import SwiftUI

enum CaptureMode: String, CaseIterable {
    case ocr = "OCR Only"
}

class SettingsManager: ObservableObject {
    @Published var isLiveModeEnabled: Bool {
        didSet { UserDefaults.standard.set(isLiveModeEnabled, forKey: "isLiveModeEnabled") }
    }
    
    @Published var captureMode: CaptureMode {
        didSet { UserDefaults.standard.set(captureMode.rawValue, forKey: "captureMode") }
    }
    
    @Published var updateInterval: Double {
        didSet {
            // Validate and clamp to safe range
            updateInterval = max(Constants.Timing.minimumLiveModeInterval,
                                min(Constants.Timing.maximumLiveModeInterval, updateInterval))
            UserDefaults.standard.set(updateInterval, forKey: "updateInterval")
        }
    }
    
    @Published var overlayOpacity: Double {
        didSet { UserDefaults.standard.set(overlayOpacity, forKey: "overlayOpacity") }
    }
    
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    
    @Published var useCustomColor: Bool {
        didSet { UserDefaults.standard.set(useCustomColor, forKey: "useCustomColor") }
    }
    
    @Published var latexColor: Color {
        didSet {
            if let hex = latexColor.toHex() {
                UserDefaults.standard.set(hex, forKey: "latexColorHex")
            }
        }
    }
    
    @Published var showPerformanceStats: Bool {
        didSet { 
            UserDefaults.standard.set(showPerformanceStats, forKey: "showPerformanceStats")
            updateMonitoringState()
        }
    }
    
    @Published var currentCPUUsage: Double = 0.0
    @Published var lastProcessingTime: Double = 0.0
    
    private let performanceMonitor = PerformanceMonitor()
    private var cpuTimer: Timer?
    
    private func updateMonitoringState() {
        cpuTimer?.invalidate()
        if showPerformanceStats {
            cpuTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.currentCPUUsage = self?.performanceMonitor.getCPUUsage() ?? 0.0
            }
        } else {
            cpuTimer = nil
            currentCPUUsage = 0.0
        }
    }
    
    init() {
        UserDefaults.standard.register(defaults: [
            "isLiveModeEnabled": false,
            "updateInterval": Constants.Timing.defaultLiveModeInterval,
            "overlayOpacity": 0.95,
            "fontSize": 28.0,
            "useCustomColor": false,
            "latexColorHex": "#FFFFFF",
            "showPerformanceStats": false,
            "captureMode": CaptureMode.ocr.rawValue
        ])
        
        self.isLiveModeEnabled = UserDefaults.standard.bool(forKey: "isLiveModeEnabled")
        let modeString = UserDefaults.standard.string(forKey: "captureMode") ?? CaptureMode.ocr.rawValue
        self.captureMode = .ocr
        self.updateInterval = UserDefaults.standard.double(forKey: "updateInterval")
        self.overlayOpacity = UserDefaults.standard.double(forKey: "overlayOpacity")
        self.fontSize = UserDefaults.standard.double(forKey: "fontSize")
        self.useCustomColor = UserDefaults.standard.bool(forKey: "useCustomColor")
        self.showPerformanceStats = UserDefaults.standard.bool(forKey: "showPerformanceStats")
        
        let hex = UserDefaults.standard.string(forKey: "latexColorHex") ?? "#FFFFFF"
        self.latexColor = Color(hex: hex) ?? .white
        
        updateMonitoringState()
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else { return nil }
        
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

func scanner(string: String) -> Scanner {
    return Scanner(string: string)
}
