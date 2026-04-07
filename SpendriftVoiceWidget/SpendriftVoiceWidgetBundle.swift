//
//  SpendriftVoiceWidgetBundle.swift
//  SpendriftVoiceWidget
//
//  Created by Cursor on 23/03/26.
//

import SwiftUI
import WidgetKit

@main
struct SpendriftVoiceWidgetBundle: WidgetBundle {
    var body: some Widget {
        VoiceLiveActivityWidget()
        QuickExpenseSmallWidget()
        CaptureHubMediumWidget()
        RecentTransactionsLargeWidget()
    }
}
