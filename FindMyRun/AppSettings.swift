//
//  AppSettings.swift
//  FindMyRun
//

import SwiftUI
import WidgetKit

@Observable
final class AppSettings {
    private static let key = "themeColorComponents"
    private static let widgetKey = "widgetEnabled"
    private static let shared = UserDefaults(suiteName: SharedRunStore.appGroupID)

    var themeColor: Color {
        didSet { persist() }
    }

    var widgetEnabled: Bool {
        didSet {
            Self.shared?.set(widgetEnabled, forKey: Self.widgetKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    init() {
        if let arr = UserDefaults.standard.array(forKey: Self.key) as? [Double], arr.count == 4 {
            themeColor = Color(red: arr[0], green: arr[1], blue: arr[2], opacity: arr[3])
        } else {
            themeColor = Color(white: 0.33)
        }
        // Default to enabled; explicit false stored in shared defaults means disabled
        if let stored = Self.shared?.object(forKey: Self.widgetKey) as? Bool {
            widgetEnabled = stored
        } else {
            widgetEnabled = true
            Self.shared?.set(true, forKey: Self.widgetKey)
        }
    }

    private func persist() {
        let ui = UIColor(themeColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        UserDefaults.standard.set([Double(r), Double(g), Double(b), Double(a)], forKey: Self.key)
    }
}

extension Color {
    /// App-wide background: light grey in light mode, dark grey (not pure black) in dark mode.
    static let appBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.13, alpha: 1)
            : UIColor.systemGroupedBackground
    })
}
