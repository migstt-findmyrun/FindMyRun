//
//  FindMyRunWidgetBundle.swift
//  FindMyRunWidget
//
//  Created by Miguel Dias on 2026-04-24.
//

import WidgetKit
import SwiftUI

@main
struct FindMyRunWidgetBundle: WidgetBundle {
    var body: some Widget {
        FindMyRunWidget()
        FindMyRunWidgetControl()
        FindMyRunWidgetLiveActivity()
    }
}
