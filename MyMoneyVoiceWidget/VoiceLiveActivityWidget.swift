//
//  VoiceLiveActivityWidget.swift
//  MyMoneyVoiceWidget
//
//  Created by Cursor on 23/03/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct VoiceLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VoiceLiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Label("Voice Transaction", systemImage: "mic.fill")
                    .font(.headline)
                Text(context.state.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "mic.fill")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.state.capitalized)
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.message)
                        .font(.caption2)
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
            } compactTrailing: {
                Text(context.state.state.prefix(1).uppercased())
            } minimal: {
                Image(systemName: "mic.fill")
            }
        }
    }
}
