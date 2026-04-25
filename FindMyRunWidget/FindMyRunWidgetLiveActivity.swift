//
//  FindMyRunWidgetLiveActivity.swift
//  FindMyRunWidget
//
//  Created by Miguel Dias on 2026-04-24.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FindMyRunWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct FindMyRunWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FindMyRunWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension FindMyRunWidgetAttributes {
    fileprivate static var preview: FindMyRunWidgetAttributes {
        FindMyRunWidgetAttributes(name: "World")
    }
}

extension FindMyRunWidgetAttributes.ContentState {
    fileprivate static var smiley: FindMyRunWidgetAttributes.ContentState {
        FindMyRunWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: FindMyRunWidgetAttributes.ContentState {
         FindMyRunWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: FindMyRunWidgetAttributes.preview) {
   FindMyRunWidgetLiveActivity()
} contentStates: {
    FindMyRunWidgetAttributes.ContentState.smiley
    FindMyRunWidgetAttributes.ContentState.starEyes
}
