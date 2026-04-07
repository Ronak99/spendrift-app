//
//  MyMoneyVoiceWidgetBundle.swift
//  MyMoneyVoiceWidget
//
//  Created by Cursor on 23/03/26.
//

import SwiftUI
import WidgetKit

@main
struct MyMoneyVoiceWidgetBundle: WidgetBundle {
    var body: some Widget {
        VoiceLiveActivityWidget()
        QuickExpenseSmallWidget()
        CaptureHubMediumWidget()
        RecentTransactionsLargeWidget()
    }
}
