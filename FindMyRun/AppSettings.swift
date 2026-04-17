//
//  AppSettings.swift
//  FindMyRun
//

import SwiftUI

@Observable
final class AppSettings {
    private static let key = "themeColorComponents"

    var themeColor: Color {
        didSet { persist() }
    }

    init() {
        if let arr = UserDefaults.standard.array(forKey: Self.key) as? [Double], arr.count == 4 {
            themeColor = Color(red: arr[0], green: arr[1], blue: arr[2], opacity: arr[3])
        } else {
            themeColor = Color(.darkGray)
        }
    }

    private func persist() {
        let ui = UIColor(themeColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        UserDefaults.standard.set([Double(r), Double(g), Double(b), Double(a)], forKey: Self.key)
    }
}
