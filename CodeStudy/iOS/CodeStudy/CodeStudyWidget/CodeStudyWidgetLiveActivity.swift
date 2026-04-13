//
//  CodeStudyWidgetLiveActivity.swift
//  CodeStudyWidget
//
//  Created by Tabber on 4/6/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct CodeStudyWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct CodeStudyWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CodeStudyWidgetAttributes.self) { context in
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

extension CodeStudyWidgetAttributes {
    fileprivate static var preview: CodeStudyWidgetAttributes {
        CodeStudyWidgetAttributes(name: "World")
    }
}

extension CodeStudyWidgetAttributes.ContentState {
    fileprivate static var smiley: CodeStudyWidgetAttributes.ContentState {
        CodeStudyWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: CodeStudyWidgetAttributes.ContentState {
         CodeStudyWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: CodeStudyWidgetAttributes.preview) {
   CodeStudyWidgetLiveActivity()
} contentStates: {
    CodeStudyWidgetAttributes.ContentState.smiley
    CodeStudyWidgetAttributes.ContentState.starEyes
}
